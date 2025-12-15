local OSCommands = require('OSCommands')
local AudioManager = {}
local DEFAULT_CONFIG = {
    text_to_speech = {
        model = "tts-1", -- The model to use for text-to-speech conversion
        voice = "alloy", -- Options: alloy, echo, fable, onyx, nova, shimmer
        speed = 1.0, -- Speech rate (0.5 to 2.0)
        output_format = "mp3", -- Output audio format (mp3 or wav)
        temp_dir = OSCommands:getTempDir()
    },
    audio_cache_limit = 50, -- Maximum number of audio files to cache
    cache_dir = OSCommands:createPathByOS(OSCommands:getTempDir(), "pulpero_audio_cache")
}

function AudioManager.new(logger, config)
    local self = setmetatable({}, { __index = AudioManager })
    if logger == nil then
        error("AudioManager logger cannot be nil")
    end
    self.logger = logger
    self.config = config or DEFAULT_CONFIG
    self.is_recording = false
    self.is_playing = false
    self.current_recording_path = nil
    self.current_playback_path = nil
    self.recording_process = nil
    self.playback_process = nil
    self.cache = {}
    -- Ensure cache directory exists
    OSCommands:ensureDir(self.config.cache_dir)
    -- Initialize backend services
    self:initializeAudioBackends()
    return self
end

function AudioManager:initializeAudioBackends()
    self.logger:debug("Initializing audio backends")

    -- Check for necessary tools/dependencies
    local has_ffmpeg = os.execute("ffmpeg -version > " .. (OSCommands:isWindows() and "NUL" or "/dev/null") .. " 2>&1") == 0
    if not has_ffmpeg then
        self.logger:error("FFmpeg not found. Audio features will be limited.")
    end

    -- Initialize recording command based on OS
    if OSCommands:isWindows() then
        self.record_cmd = 'ffmpeg -f dshow -i audio="Microphone Array (Realtek(R) Audio)" -ar %d -ac %d -t %d -y "%s"'
    elseif OSCommands:isDarwin() then
        self.record_cmd = 'ffmpeg -f avfoundation -i ":0" -ar %d -ac %d -t %d -y "%s"'
    else
        self.record_cmd = 'ffmpeg -f alsa -i default -ar %d -ac %d -t %d -y "%s"'
    end

    -- Initialize playback command based on OS
    if OSCommands:isWindows() then
        self.play_cmd = 'start /b "" powershell -c (New-Object Media.SoundPlayer "%s").PlaySync()'
    elseif OSCommands:isDarwin() then
        self.play_cmd = 'afplay "%s"'
    else
        self.play_cmd = 'aplay "%s"'
    end
    self.logger:debug("Audio backends initialized")
end

-- Convert text to speech using TTS model
function AudioManager:textToSpeech(text)
    if not text or text == "" then
        self.logger:error("Empty text provided for TTS")
        return nil
    end
    self.logger:debug("Converting text to speech", { text_length = #text })
    local cfg = self.config.text_to_speech
    local output_path = OSCommands:createPathByOS(
        cfg.temp_dir,
        "pulpero_tts_" .. os.time() .. "." .. cfg.output_format
    )
    -- Here you'd integrate with your text-to-speech model
    -- This is a placeholder implementation that would need to be replaced
    -- with your actual model integration
    -- Example command for a hypothetical TTS system
    local text_file_path = output_path .. ".txt"
    local text_file = io.open(text_file_path, "w")
    if not text_file then
        self.logger:error("Failed to create temporary text file for TTS")
        return nil
    end
    text_file:write(text)
    text_file:close()
    local cmd = string.format(
        "tts --model %s --voice %s --speed %.1f --text-file %s --output %s",
        cfg.model,
        cfg.voice,
        cfg.speed,
        text_file_path,
        output_path
    )
    self.logger:debug("Running TTS command", { cmd = cmd })
    local success = os.execute(cmd)
    os.remove(text_file_path)
    if not success then
        self.logger:error("TTS generation failed")
        return nil
    end
    table.insert(self.cache, output_path)
    self:manageCache()
    self.logger:debug("TTS generation completed", { path = output_path })
    return output_path
end

function AudioManager:playAudio(audio_path)
    if self.is_playing then
        self.logger:debug("Already playing audio, stopping current playback")
        self:stopPlayback()
    end
    if not OSCommands:fileExists(audio_path) then
        self.logger:error("Audio file does not exist", { path = audio_path })
        return false
    end
    local cmd = string.format(self.play_cmd, audio_path)
    self.logger:debug("Playing audio", { cmd = cmd })
    if OSCommands:isWindows() then
        self.playback_process = vim.fn.jobstart('cmd /c ' .. cmd)
    else
        self.playback_process = vim.fn.jobstart(cmd)
    end
    self.is_playing = true
    self.current_playback_path = audio_path
    vim.fn.jobwait({self.playback_process}, 0)
    vim.schedule(function()
        self.is_playing = false
        self.playback_process = nil
        self.logger:debug("Playback completed")
    end)
    return true
end

function AudioManager:stopPlayback()
    if not self.is_playing then
        return false
    end
    if self.playback_process then
        vim.fn.jobstop(self.playback_process)
        self.playback_process = nil
    end
    self.is_playing = false
    self.logger:debug("Playback stopped")
    return true
end

function AudioManager:speak(text)
    local audio_path = self:textToSpeech(text)
    if not audio_path then
        return false
    end
    return self:playAudio(audio_path)
end

function AudioManager:manageCache()
    local limit = self.config.audio_cache_limit

    while #self.cache > limit do
        local oldest_file = table.remove(self.cache, 1)
        if OSCommands:fileExists(oldest_file) then
            os.remove(oldest_file)
            self.logger:debug("Removed cached audio file", { path = oldest_file })
        end
    end
end

function AudioManager:clearCache()
    for _, file_path in ipairs(self.cache) do
        if OSCommands:fileExists(file_path) then
            os.remove(file_path)
        end
    end
    self.cache = {}
    self.logger:debug("Audio cache cleared")
end

return AudioManager
