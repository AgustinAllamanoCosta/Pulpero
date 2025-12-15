local CodeManager = {}
local luasql = require("luasql.sqlite3")
local JSON = require("JSON")
local OSCommands = require("OSCommands")

function CodeManager.new(logger, data_base_path)
    local self = setmetatable({}, { __index = CodeManager })
    self.data_base_full_path = data_base_path
    self.connection = nil
    self.logger = logger
    return self
end

function CodeManager:connect_to_database()
    local client = luasql.sqlite3()
    self.connection = client:connect(self.data_base_full_path)

    if not self.connection then
        self.logger:error("Failed to open database: " .. self.data_base_full_path)
        return
    end

    local create_table_sql = [[
        CREATE TABLE IF NOT EXISTS code_chunks (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            content TEXT NOT NULL,
            embedding TEXT NOT NULL,  -- JSON array of floats
            file_path TEXT NOT NULL,
            chunk_type TEXT NOT NULL, -- 'function', 'class', 'file', 'import'
            symbol_name TEXT,
            line_start INTEGER,
            line_end INTEGER,
            metadata TEXT,           -- JSON metadata
            created_at INTEGER DEFAULT (strftime('%s', 'now')),
            updated_at INTEGER DEFAULT (strftime('%s', 'now'))
        );

        CREATE INDEX IF NOT EXISTS idx_file_path ON code_chunks(file_path);
        CREATE INDEX IF NOT EXISTS idx_chunk_type ON code_chunks(chunk_type);
        CREATE INDEX IF NOT EXISTS idx_symbol_name ON code_chunks(symbol_name);
    ]]

    local result = self.connection:execute(create_table_sql)
    if result ~= 0 then
        self.logger:error("Failed to create database tables: " .. self.connection:errmsg())
    else
        self.logger:debug("Database initialized successfully")
    end
    self.connection:commit()
end

function CodeManager:close()
    if self.connection then
        self.connection:close()
        self.logger:debug("Database connection closed")
    end
end

function CodeManager:add_chunk(chunk_data)
    if not chunk_data.content or not chunk_data.embedding then
        self.logger:error("Missing required fields: content and embedding")
        return false
    end

    local stmt = self.connection:prepare([[
        INSERT INTO code_chunks
        (content, embedding, file_path, chunk_type, symbol_name, line_start, line_end, metadata)
        VALUES (?, ?, ?, ?, ?, ?, ?, ?)
    ]])

    if not stmt then
        self.logger:error("Failed to prepare insert statement: " .. self.connection:errmsg())
        return false
    end

    local embedding_json = JSON.encode(chunk_data.embedding)
    local metadata_json = chunk_data.metadata and JSON.encode(chunk_data.metadata) or "{}"

    stmt:bind_values(
        chunk_data.content,
        embedding_json,
        chunk_data.file_path or "",
        chunk_data.chunk_type or "unknown",
        chunk_data.symbol_name,
        chunk_data.line_start,
        chunk_data.line_end,
        metadata_json
    )

    local result = stmt:step()
    stmt:finalize()

    if result == luasql.DONE then
        self.logger:debug("Added chunk", {
            type = chunk_data.chunk_type,
            symbol = chunk_data.symbol_name,
            file = chunk_data.file_path
        })
        return true
    else
        self.logger:error("Failed to insert chunk: " .. self.db:errmsg())
        return false
    end
end

function CodeManager:cosine_similarity(vec1, vec2)
    if #vec1 ~= #vec2 then
        return 0
    end

    local dot_product = 0
    local norm_a, norm_b = 0, 0

    for i = 1, #vec1 do
        dot_product = dot_product + vec1[i] * vec2[i]
        norm_a = norm_a + vec1[i] * vec1[i]
        norm_b = norm_b + vec2[i] * vec2[i]
    end

    local norm_product = math.sqrt(norm_a) * math.sqrt(norm_b)
    if norm_product == 0 then
        return 0
    end

    return dot_product / norm_product
end

function CodeManager:semantic_search(query_embedding, options)
    local limit = options.limit or 10
    local chunk_type_filter = options.chunk_type
    local file_path_filter = options.file_path
    local min_similarity = options.min_similarity or 0.1

    local where_conditions = {}
    local bind_values = {}
    local results = {}

    if chunk_type_filter then
        table.insert(where_conditions, "chunk_type = ?")
        table.insert(bind_values, chunk_type_filter)
    end

    if file_path_filter then
        table.insert(where_conditions, "file_path LIKE ?")
        table.insert(bind_values, "%" .. file_path_filter .. "%")
    end

    local where_clause = ""
    if #where_conditions > 0 then
        where_clause = "WHERE " .. table.concat(where_conditions, " AND ")
    end

    local query = string.format([[
        SELECT id, content, embedding, file_path, chunk_type, symbol_name,
               line_start, line_end, metadata
        FROM code_chunks
        %s
        ORDER BY id
    ]], where_clause)

    local stmt = self.db:prepare(query)
    if not stmt then
        self.logger:error("Failed to prepare search query: " .. self.db:errmsg())
        return results
    end

    for i, value in ipairs(bind_values) do
        stmt:bind_value(i, value)
    end

    while stmt:step() == luasql.ROW do
        local row = stmt:get_named_values()

        local embedding_success, embedding = pcall(JSON.decode, row.embedding)
        if not embedding_success then
            self.logger:error("Failed to decode embedding for chunk " .. row.id)
            goto continue
        end

        local similarity = self:cosine_similarity(query_embedding, embedding)

        if similarity >= min_similarity then
            local metadata = {}
            if row.metadata and row.metadata ~= "" then
                local metadata_success, parsed_metadata = pcall(JSON.decode, row.metadata)
                if metadata_success then
                    metadata = parsed_metadata
                end
            end

            table.insert(results, {
                id = row.id,
                content = row.content,
                file_path = row.file_path,
                chunk_type = row.chunk_type,
                symbol_name = row.symbol_name,
                line_start = row.line_start,
                line_end = row.line_end,
                metadata = metadata,
                similarity = similarity
            })
        end

        ::continue::
    end

    stmt:finalize()

    table.sort(results, function(a, b) return a.similarity > b.similarity end)

    local limited_results = {}
    for i = 1, math.min(limit, #results) do
        table.insert(limited_results, results[i])
    end

    return limited_results
end

function CodeManager:get_embedding(text)
    local escaped_text = text:gsub('"', '\\"')
    local cmd = string.format('python3 lua/pulpero/core/managers/code_data_base/processCode.py "%s"', escaped_text)
    local result = OSCommands:execute_command(cmd)

    local success, parsed = pcall(JSON.decode, result)
    if success and parsed.embedding then
        return parsed.embedding
    else
        error("Embedding failed: " .. (parsed.error or "Unknown error"))
    end
end

return CodeManager
