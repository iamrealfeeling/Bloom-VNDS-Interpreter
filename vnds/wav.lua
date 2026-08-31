-- ============================================================================
--  vnds/wav.lua
--  Minimal RIFF/WAVE (PCM) reader & writer used by the interpreter.
--
--  The PSP audio backend (PSPAALIB via LuaPlayerYT) can play ".wav" files
--  directly through the WAV_x channels, but only *uncompressed PCM* data.
--  These helpers let the engine introspect/validate a WAV and build one from
--  raw PCM samples (used by the optional AAC->WAV conversion path).
-- ============================================================================

local wav = {}

-------------------------------------------------------------------------------
-- Read a little-endian unsigned integer from a byte string.
-------------------------------------------------------------------------------
local function le16(b, o) return b:byte(o) + b:byte(o + 1) * 256 end
local function le32(b, o)
    return b:byte(o) + b:byte(o + 1) * 256 + b:byte(o + 2) * 65536 + b:byte(o + 3) * 16777216
end

-------------------------------------------------------------------------------
-- Parse a WAV file loaded entirely into a string.
-- Returns: { sampleRate, channels, bitsPerSample, data, dataLen } or nil, err
-------------------------------------------------------------------------------
function wav.parse(data)
    if not data or #data < 44 then
        return nil, "file too small"
    end
    if data:sub(1, 4) ~= "RIFF" or data:sub(9, 12) ~= "WAVE" then
        return nil, "not a RIFF/WAVE file"
    end

    local pos = 13
    local fmt, sampleRate, channels, bits, dataChunk, dataLen
    dataLen = 0
    dataChunk = nil

    while pos < #data do
        local id = data:sub(pos, pos + 3)
        local size = le32(data, pos + 4)
        local body = pos + 8

        if id == "fmt " then
            fmt = le16(data, body)
            channels = le16(data, body + 2)
            sampleRate = le32(data, body + 4)
            bits = le16(data, body + 14)
        elseif id == "data" then
            dataChunk = body
            dataLen = size
            break
        end
        pos = body + size + (size % 2) -- chunks are word-aligned
    end

    if not dataChunk then
        return nil, "no data chunk"
    end

    return {
        format = fmt or 1,
        sampleRate = sampleRate or 44100,
        channels = channels or 1,
        bitsPerSample = bits or 16,
        data = data:sub(dataChunk, dataChunk + dataLen - 1),
        dataLen = dataLen,
    }
end

-------------------------------------------------------------------------------
-- Build a 16-bit PCM mono/stereo WAV from a table/string of raw samples.
-- samples: string of 16-bit little-endian signed PCM, or a numeric table.
-- Returns the full WAV file as a string.
-------------------------------------------------------------------------------
function wav.build(samples, sampleRate, channels, bits)
    sampleRate = sampleRate or 44100
    channels = channels or 1
    bits = bits or 16

    local raw
    if type(samples) == "string" then
        raw = samples
    else
        -- numeric table -> little endian 16-bit
        local parts = {}
        for i = 1, #samples do
            local v = math.floor(samples[i])
            if v > 32767 then v = 32767 end
            if v < -32768 then v = -32768 end
            parts[i] = string.char(v % 256, math.floor(v / 256) % 256)
        end
        raw = table.concat(parts)
    end

    local byteRate = sampleRate * channels * (bits / 8)
    local blockAlign = channels * (bits / 8)
    local dataLen = #raw
    local riffLen = 36 + dataLen

    local function u16(v)
        v = math.floor(v)
        return string.char(v % 256, math.floor(v / 256) % 256)
    end
    local function u32(v)
        v = math.floor(v)
        return string.char(v % 256, math.floor(v / 256) % 256,
            math.floor(v / 65536) % 256, math.floor(v / 16777216) % 256)
    end

    local head = {}
    head[#head + 1] = "RIFF"
    head[#head + 1] = u32(riffLen)
    head[#head + 1] = "WAVE"
    head[#head + 1] = "fmt "
    head[#head + 1] = u32(16)          -- PCM fmt chunk size
    head[#head + 1] = u16(1)           -- PCM
    head[#head + 1] = u16(channels)
    head[#head + 1] = u32(sampleRate)
    head[#head + 1] = u32(byteRate)
    head[#head + 1] = u16(blockAlign)
    head[#head + 1] = u16(bits)
    head[#head + 1] = "data"
    head[#head + 1] = u32(dataLen)

    return table.concat(head) .. raw
end

-------------------------------------------------------------------------------
-- Write a WAV to disk (used by conversion tools running on the PSP side if a
-- decoder library was ever added). Usually you convert on PC instead.
-------------------------------------------------------------------------------
function wav.writeFile(path, samples, sampleRate, channels, bits)
    local f = io.open(path, "wb")
    if not f then return false end
    f:write(wav.build(samples, sampleRate, channels, bits))
    f:close()
    return true
end

return wav
