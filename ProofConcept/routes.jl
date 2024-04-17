using Genie.Router, Genie, Genie.Renderer.Html, Genie.Requests
using Sound
using HTTP
using JSON
using PortAudio
using Dates
using Genie.Assets
using DSP
using MIRT: interp1
using Plots

# Vibrato Lesson Variables
global vibLesDep = 0
global vibLesOF = 0

# Tremolo and Vibrato
global tremDepth = 0
global tremOscillatingFreq = 0
global vibOscillatingFreq = 0
global vibDepth = 0

# Misc variables
global mode = 1 # waveform mode
global octave = 0 # octave num
global amp = 1 # amplitude
global harmonicsNum = 1 # num of harmonics

# AHDSR variables
global a = 1
global h = 1
global d = 1
global s = 1
global r = 1

# Distortion Variables
global dH = 0
global dP = 0

Genie.config.websockets_server = true # enable the websockets server

route("/") do
  html(Renderer.filepath("pages/mainpage.jl.html"))
end

# Pages

route("/vibratoLesson", method=GET) do
  html(Renderer.filepath("pages/vibratolesson.jl.html"))
end

route("/aboutus", method=GET) do
  html(Renderer.filepath("pages/AboutUs.jl.html"))
end

route("/ahdsrLesson", method=GET) do
  html(Renderer.filepath("pages/AHDSRlesson.html"))
end

route("/distortionLesson", method=GET) do
  html(Renderer.filepath("pages/distortionlesson.html"))
end

route("/vwhLesson", method=GET) do
  html(Renderer.filepath("pages/volwavharmlesson.html"))
end

route("/vibratolessonOF", method=POST) do
  post_data = rawpayload() # jsonpayload("data")
  # println(post_data)
  global vibLesOF = parse(Int, post_data)
end

route("/vibratolessondepth", method=POST) do
  post_data = rawpayload() # jsonpayload("data")
  # println(post_data)
  global vibLesDep = parse(Int, post_data)
end

route("/vibratolessonplay", method=POST) do
  S = 8192 # Sampling Rate
  fo = 440  # Frequency
  t = (1:S/2) / S

  ph = 2pi * fo * t .+ vibLesDep * sin.(2pi * vibLesOF * t) # phase equation

  x = 2 * cos.(ph)
  sound(x, S)
end

route("/tremoloLesson", method=GET) do
  html(Renderer.filepath("pages/tremololesson.jl.html"))
end

route("/piano", method=GET) do
  html(Renderer.filepath("pages/piano.jl.html"))
end

# button click input
route("/piano", method=POST) do
  post_data = rawpayload() # payload data from JS 
  # println(post_data)

  # json_obj = JSON.parse(post_data)
  # num = json_obj["data"]
  # println(num)

  f = 174.61 * (2.0^(1 / 12))^(parse(Int64, post_data) - 1 + octave * 12) # Midi Equation
  # println(f)

  # timing test: first log
  dt = Dates.unix2datetime(Base.time())
  println(Dates.second(dt), " ", Dates.millisecond(dt))

  playSound(f)

  # timing test: second log
  dz = Dates.unix2datetime(Base.time())
  println(Dates.second(dz), " ", Dates.millisecond(dz))
  println(Dates.second(dz) - Dates.second(dt), " ", Dates.millisecond(dz) - Dates.millisecond(dt))
end

# keyboard input
route("/pianoc", method=POST) do
  post_data = rawpayload() # jsonpayload("data")
  # println(post_data)

  # json_obj = JSON.parse(post_data)
  # num = json_obj["data"]
  # println(num)

  # conversionArr = [65, 87, 83, 69, 68, 82, 70, 71, 89, 72, 85, 74, 75, 79, 76, 80, 186, 219, 222, 13, 103, 100, 104, 101]
  # dat = parse(Int64, post_data)
  # println(dat)

  # conversion array for button text input
  conversionArr = ["a", "w", "s", "e", "d", "r", "f", "g", "y", "h", "u", "j", "k", "o", "l", "p", ";", "[", "'", "Enter", "7", "4", "8", "5"]

  # find the element index (converted midi number)
  num = findfirst(==(post_data), conversionArr)
  # println(num)

  # found button, find and play note
  if num !== nothing
    f = 174.61 * (2.0^(1 / 12))^(num - 1 + octave * 12) # Midi Equation
    playSound(f)                          # Play the note
  end
end

# Using the frequency from buttons, find the relevant waveform and play it.
function playSound(f)
  S = 8192 # sampling rate in Hz
  N = Int(0.5 * S)
  t = (0:N-1) / S
  x = 0

  # Applying waveform and vibrato
  if mode == "1"
    x = amp .* abs.(2 .* (t * f .- floor.(t * f .+ 0.5) .+ vibDepth * sin.(2pi * vibOscillatingFreq * t))) .- 1 #Triangle Wave
  elseif mode == "2"
    x = amp / 2 .* sign.(cos.(2 * pi * f * t .+ vibDepth * sin.(2pi * vibOscillatingFreq * t))) # square wave
  elseif mode == "3"
    x = amp .* (t * f .- floor.(t * f .+ 0.5) .+ vibDepth * sin.(2pi * vibOscillatingFreq * t)) #Sawtooth wave
  elseif mode == "5"
    tri = amp .* abs.(2 .* (t * f .- floor.(t * f .+ 0.5) .+ vibDepth * sin.(2pi * vibOscillatingFreq * t))) .- 1
    x = tri .* tri
  else
    x = 2 * amp * cos.(2π * t * f .+ vibDepth * sin.(2pi * vibOscillatingFreq * t)) # sinusoidal wave
  end

  println(harmonicsNum)

  # Applying harmonics
  if harmonicsNum > 1
    for p in 2:harmonicsNum
      if mode == "1"
        j = 2 * p - 1
        x += (amp) .* abs.(2 .* (t * j * f .- floor.(t * j * f .+ 0.5) .+ vibDepth * sin.(2pi * vibOscillatingFreq * t))) .- 1 #Triangle Wave
      elseif mode == "2"
        j = 2 * p - 1
        x += amp / 2 .* sign.(cos.(2 * pi * j * f * t .+ vibDepth * sin.(2pi * vibOscillatingFreq * t))) # square wave
      elseif mode == "3"
        j = p
        x += (amp / j) .* (t * j * f .- floor.(t * j * f .+ 0.5) .+ vibDepth * sin.(2pi * vibOscillatingFreq * t)) #Sawtooth wave
      elseif mode == "5"
        j = 2 * p - 1
        tri = (amp) .* abs.(2 .* (t * j * f .- floor.(t * j * f .+ 0.5) .+ vibDepth * sin.(2pi * vibOscillatingFreq * t))) .- 1 # semisine
        x += tri .* tri
      else
        j = p
        x += 2 * amp * cos.(2π * t * j * f .+ vibDepth * sin.(2pi * vibOscillatingFreq * t)) # sinusoidal wave
      end
    end
  end

  # Applying tremolo
  if tremDepth > 0
    e = 1 - tremDepth .+ tremDepth * sin.(2pi * t * tremOscillatingFreq) # Envelope
    signal = x .* e
  else
    signal = x
  end


  # Adding Additional Harmonics 
  # fsignal = envelope1(signal, t, f)
  sig = signal

  for harms in 1:dH
    signal = signal + 0.5 * sig .^ (harms * dP)
  end

  # Applying AHDSR
  duration = 0.5

  adsr_time = [0, 0.5, 0.60, 0.65, 1] * duration
  adsr_vals = [a, h, d, s, r]
  t = 1/S:1/S:duration
  env = interp1(adsr_time, adsr_vals, t)

  signal = env .* signal


  # Output Signal
  # Sound() tends to have a larger delay. As such, shifted to PortAudioStream to remove an additional piece of lag.
  # sound(signal, S)

  PortAudioStream(0, 2; samplerate=S, latency=0.05) do stream
    write(stream, signal)
  end
  plot(signal)
  savefig("plot.png")
end

function envelope1(signal, t, f)

end

route("/waveform", method=POST) do
  post_data = rawpayload() # jsonpayload("data")
  # println(post_data)
  global mode = post_data
end

route("/tremoloOF", method=POST) do
  post_data = rawpayload() # jsonpayload("data")
  # println(post_data)
  global tremOscillatingFreq = parse(Int, post_data)
end

route("/tremoloDepth", method=POST) do
  post_data = rawpayload() # jsonpayload("data")
  # println(post_data)
  global tremDepth = parse(Int, post_data)
end

route("/vibratoOF", method=POST) do
  post_data = rawpayload() # jsonpayload("data")
  # println(post_data)
  global vibOscillatingFreq = parse(Int, post_data)
end

route("/vibratoDepth", method=POST) do
  post_data = rawpayload() # jsonpayload("data")
  # println(post_data)
  global vibDepth = parse(Int, post_data)
  # println(vibDepth)
end

route("/octaveShift", method=POST) do
  post_data = rawpayload() # jsonpayload("data")
  # println(post_data)
  shift = parse(Int, post_data)
  global octave += shift
  # println(octave)
end

route("/octaveReset", method=POST) do
  post_data = rawpayload() # jsonpayload("data")
  # println(post_data)
  shift = parse(Int, post_data)
  global octave = 0
  # println(octave)
end

route("/volume", method=POST) do
  post_data = rawpayload() # jsonpayload("data")
  # println(post_data)
  shift = parse(Int, post_data)
  global amp = shift / 10
  # println(amp)
end

route("/attack", method=POST) do
  post_data = rawpayload() # jsonpayload("data")
  # println(post_data)
  shift = parse(Int, post_data)
  global a = shift / 10
end
route("/hold", method=POST) do
  post_data = rawpayload() # jsonpayload("data")
  # println(post_data)
  shift = parse(Int, post_data)
  global h = shift / 10
end
route("/sustain", method=POST) do
  post_data = rawpayload() # jsonpayload("data")
  # println(post_data)
  shift = parse(Int, post_data)
  global s = shift / 10
end
route("/decay", method=POST) do
  post_data = rawpayload() # jsonpayload("data")
  # println(post_data)
  shift = parse(Int, post_data)
  global d = shift / 10
end

route("/release", method=POST) do
  post_data = rawpayload() # jsonpayload("data")
  # println(post_data)
  shift = parse(Int, post_data)
  global r = shift / 10
end

route("/harmonics", method=POST) do
  post_data = rawpayload() # jsonpayload("data")
  # println(post_data)
  h = parse(Int, post_data)
  global harmonicsNum = h
end

route("/distortH", method=POST) do
  post_data = rawpayload() # jsonpayload("data")
  # println(post_data)
  h = parse(Int, post_data)
  global dH = h
end

route("/distortP", method=POST) do
  post_data = rawpayload() # jsonpayload("data")
  # println(post_data)
  h = parse(Int, post_data)
  global dP = 10^h
end

up()