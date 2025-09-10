local CodeManager = require("code_data_base.manager")
local OSCommands = require("OSCommands")
local Logger = require("Logger")
local luaunit = require('luaunit')

local logger = Logger.new("Code_Data_Base_Test", true)

function test_should_create_a_new_code_data_base_on_path()
    local data_base_path = OSCommands:create_path_by_OS(OSCommands:get_work_dir(), "test_code_base.db")

    local code_manager = CodeManager.new(logger, data_base_path)

    code_manager:connect_to_database()
    OSCommands:delete_file(data_base_path)
    luaunit.assertNotNil(code_manager.connection)
end

function test_should_encode_a_code_into_a_vector()
    local code_manager = CodeManager.new(logger, nil)

    local vectors_result = code_manager:get_embedding([[
const axios = require('axios');

const scanSiteCookies = async () => {

    const siteURL = 'http://mercury.picoctf.net:17781/check';
    const rangeOfAttack = 20;

    for (let cookie = 0; cookie <= rangeOfAttack; cookie++) {
        const headers = {
            'Cookie': `name=${cookie}`
        };

        try {

            const response = await axios.get(siteURL, { headers });

            if (response.status === 200) {
                console.log(String(response.data));
            }
        } catch (error) {
            console.log('some error', error.message);
        }
    }

}

scanSiteCookies();
    ]])

    print(vectors_result)
    luaunit.assertNotNil(vectors_result)
end

local runner = luaunit.LuaUnit.new()
runner:setOutputType("text")
os.exit(runner:runSuite())
