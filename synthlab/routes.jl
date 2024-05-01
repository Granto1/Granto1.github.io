using Genie.Router, Genie, Genie.Renderer.Html, Genie.Requests
using HTTP
using JSON
using PortAudio
using Dates
using Genie.Assets
using DSP
using MIRT: interp1
using Plots

# Tremolo and Vibrato
global tremDepth = 0
global tremOscillatingFreq = 0
global trem = -1

global vibOscillatingFreq = 0
global vibDepth = 0
global vib = -1

# Misc variables
global mode = 1 # waveform mode
global octave = 0 # octave num
global amp = 1 # amplitude
global harmonicsNum = 1 # num of harmonics

# AHDSR variables
global a = 0
global h = 1
global d = 1
global s = 1
global r = 1
global ahdsr = -1

# Distortion Variables
global gain = 0
global cutoff = 0
global distort = -1

Genie.config.websockets_server = true # enable the websockets server

# -- Renderer Paths --
# Pages

route("/") do
  html(Renderer.filepath("public/pages/index.html"))
end

route("/vibratoLesson", method=GET) do
  html(Renderer.filepath("public/pages/vibratolesson.html"))
end

route("/aboutus", method=GET) do
  html(Renderer.filepath("public/pages/AboutUs.html"))
end

route("/ahdsrLesson", method=GET) do
  html(Renderer.filepath("public/pages/AHDSRlesson.html"))
end

route("/distortionLesson", method=GET) do
  html(Renderer.filepath("public/pages/distortionlesson.html"))
end

route("/vwhLesson", method=GET) do
  html(Renderer.filepath("public/pages/volwavharmlesson.html"))
end

route("/tremoloLesson", method=GET) do
  html(Renderer.filepath("public/pages/tremololesson.html"))
end

route("/piano", method=GET) do
  html(Renderer.filepath("public/pages/piano.html"))
end
# --------------------

# Lesson Methods

route("/plotPlayVibrato", method=POST) do
  post_data = rawpayload() # jsonpayload("data")
  playParse = parse(Int, post_data)

  S = 8192 # Sampling Rate
  f = 440  # Frequency
  t = (1:S/2) / S

  ph = 2pi * f * t .+ vibDepth * sin.(2pi * vibOscillatingFreq * t) # phase equation

  x = 2 * cos.(ph)

  if playParse == 1
    PortAudioStream(0, 2; samplerate=S, latency=0.05) do stream
      write(stream, x)
    end
  end

  plot(x, title="Sinusoidal Wave with Vibrato", xlabel="Samples", ylabel="Amplitude")
  xlims!(0, 440)
  savefig("public/assets/images/plotVibrato.png")
end

route("/plotPlayAHDSR", method=POST) do
  post_data = rawpayload() # jsonpayload("data")
  playParse = parse(Int, post_data)
  duration = 0.5
  S = 8192
  f = 440  # Frequency
  t = (1:S/2) / S

  x = cos.(2π * t * f)
  adsr_time = [0, a * 0.25, 0.26 + 0.14 * h, 0.41 + 0.19 * d, 0.61 + 0.38 * r, 1] * duration
  adsr_vals = [0, 1, 1, s, s, 0]

  t = 1/S:1/S:duration
  env = interp1(adsr_time, adsr_vals, t)

  x = x .* env

  if playParse == 1
    PortAudioStream(0, 2; samplerate=S, latency=0.05) do stream
      write(stream, x)
    end
  end
  plot(x, title="Sinusoidal Wave with AHDSR Effects", xlabel="Samples", ylabel="Amplitude")
  savefig("public/assets/images/plotAHDSR.png")
end

route("/plotPlayDistortion", method=POST) do
  post_data = rawpayload() # jsonpayload("data")
  playParse = parse(Int, post_data)

  S = 8192
  f = 440  # Frequency
  t = (1:S/2) / S

  x = cos.(2π * t * f)

  signal = zeros(length(x))
  for i in 1:length(x)
    if abs(x[i]) > cutoff
      signal[i] = sign(x[i]) * (cutoff + (1 - cutoff) * exp(-gain * (abs(x[i]) - cutoff)))
    else
      signal[i] = x[i]
    end
  end

  if playParse == 1
    PortAudioStream(0, 2; samplerate=S, latency=0.05) do stream
      write(stream, signal)
    end
  end
  plot(signal, title="Sinusoidal Wave with Harmonic Distortion", xlabel="Samples", ylabel="Amplitude")
  xlims!(0, 440)
  savefig("public/assets/images/plotDistortion.png")

end

route("/plotPlayTremolo", method=POST) do
  post_data = rawpayload() # jsonpayload("data")
  playParse = parse(Int, post_data)

  S = 8192
  f = 440  # Frequency
  t = (1:S/2) / S

  x = cos.(2π * t * f)

  e = 1 - tremDepth .+ tremDepth * sin.(2pi * t * tremOscillatingFreq) # Envelope
  signal = x .* e
  println(tremDepth)

  if playParse == 1
    PortAudioStream(0, 2; samplerate=S, latency=0.05) do stream
      write(stream, signal)
    end
  end
  plot(signal, title="Sinusoidal Wave with Tremolo", xlabel="Samples", ylabel="Amplitude")
  savefig("public/assets/images/plotTremolo.png")
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

  phi = 0
  if vib == 1
    phi = vibDepth * sin.(2pi * vibOscillatingFreq * t)
  else
    phi = 0
  end

  # Applying waveform and vibrato
  tempwav = ""
  if mode == "1"
    x = amp .* abs.(2 .* (t * f .- floor.(t * f .+ 0.5) .+ phi)) .- 1 #Triangle Wave
    tempwav = "Triangle"
  elseif mode == "2"
    x = amp / 2 .* sign.(cos.(2 * pi * f * t .+ phi)) # square wave
    tempwav = "Square"
  elseif mode == "3"
    x = amp .* (t * f .- floor.(t * f .+ 0.5) .+ phi) #Sawtooth wave
    tempwav = "Sawtooth"
  elseif mode == "5"
    tri = amp .* abs.(2 .* (t * f .- floor.(t * f .+ 0.5) .+ phi)) .- 1
    x = tri .* tri
    tempwav = "SemiSine"
  else
    x = 2 * amp * cos.(2π * t * f .+ phi) # sinusoidal wave
    tempwav = "Sine"
  end

  # println(harmonicsNum)

  # Applying harmonics
  if harmonicsNum > 1
    for p in 2:harmonicsNum
      if mode == "1"
        j = 2 * p - 1
        x += (amp) .* abs.(2 .* (t * j * f .- floor.(t * j * f .+ 0.5) .+ phi)) .- 1 #Triangle Wave
      elseif mode == "2"
        j = 2 * p - 1
        x += amp / 2 .* sign.(cos.(2 * pi * j * f * t .+ phi)) # square wave
      elseif mode == "3"
        j = p
        x += (amp / j) .* (t * j * f .- floor.(t * j * f .+ 0.5) .+ phi) #Sawtooth wave
      elseif mode == "5"
        j = 2 * p - 1
        tri = (amp) .* abs.(2 .* (t * j * f .- floor.(t * j * f .+ 0.5) .+ phi)) .- 1 # semisine
        x += tri .* tri
      else
        j = p
        x += 2 * amp * cos.(2π * t * j * f .+ phi) # sinusoidal wave
      end
    end
  end

  # Applying tremolo
  if trem == 1
    if tremDepth > 0
      e = 1 - tremDepth .+ tremDepth * sin.(2pi * t * tremOscillatingFreq) # Envelope
      sig = x .* e
    else
      sig = x
    end
  else
    sig = x
  end

  # Applying Distortion
  signal = zeros(length(sig))
  if distort == 1
    for i in 1:length(x)
      if abs(x[i]) > cutoff
        signal[i] = sign(sig[i]) * (cutoff + (1 - cutoff) * exp(-gain * (abs(sig[i]) - cutoff)))
      else
        signal[i] = sig[i]
      end
    end
  else
    signal = sig
  end

  # Applying AHDSR
  if ahdsr == 1
    duration = 0.5
    adsr_time = [0, a * 0.25, 0.26 + 0.14 * h, 0.41 + 0.19 * d, 0.61 + 0.38 * r, 1] * duration
    println(a)
    adsr_vals = [0, 1, 1, s, s, 0]

    t = 1/S:1/S:duration
    env = interp1(adsr_time, adsr_vals, t)
    signal = signal .* env
  else
    signal = signal
  end


  # Output Signal
  # Sound() tends to have a larger delay. As such, shifted to PortAudioStream to remove an additional piece of lag.
  # sound(signal, S)

  PortAudioStream(0, 2; samplerate=S, latency=0.05) do stream
    write(stream, signal)
  end

  # Autocorrelation to verify the note number
  println(mode)
  freqs = 174.61 * (2.0^(1 / 12)) .^ ((1:24) .- 1 .+ octave * 12)
  corr = 0
  if mode == "1"
    corr = (abs.(2 .* (freqs * (1:N)' / S .- floor.(freqs * (1:N)' / S .+ 0.5))) .-1) * signal #Triangle
  elseif mode == "2"
    corr = sign.(cos.(2 * pi * freqs * (1:N)' / S)) * signal #square
  elseif mode == "3"
    corr = (freqs * (1:N)' / S  .- floor.(freqs * (1:N)' / S .+ 0.5)) * signal #Sawtooth
  else
    corr = cos.(2pi * freqs * (1:N)' / S) * signal #sine
  end
  index = argmax(corr)
  if index > 12
    index -= 12
  else
    index = index
  end
  notes = ["F", "F#", "G", "G#", "A", "A#", "B", "C", "C#", "D", "D#", "E"]
  note = notes[index]

  outputStr = string(tempwav, " wave: ", note)

  # Update the Plot
  plot(signal, title=outputStr, xlabel="Samples", ylabel="Amplitude")
  savefig("public/assets/images/plot.png")
end

# -- Variable Updating POST-Methods --

route("/waveform", method=POST) do
  post_data = rawpayload() # jsonpayload("data")
  # println(post_data)
  global mode = post_data
end

route("/tremoloOF", method=POST) do
  post_data = rawpayload()
  # println(post_data)
  global tremOscillatingFreq = parse(Int, post_data)
end

route("/tremoloDepth", method=POST) do
  post_data = rawpayload()
  # println(post_data)
  global tremDepth = parse(Int, post_data)
end

route("/vibratoOF", method=POST) do
  post_data = rawpayload()
  # println(post_data)
  global vibOscillatingFreq = parse(Int, post_data)
  print(vibOscillatingFreq)
end

route("/vibratoDepth", method=POST) do
  post_data = rawpayload()
  # println(post_data)
  global vibDepth = parse(Int, post_data)
  println(vibDepth)
end

route("/octaveShift", method=POST) do
  post_data = rawpayload()
  # println(post_data)
  shift = parse(Int, post_data)
  global octave += shift
  # println(octave)
end

route("/octaveReset", method=POST) do
  post_data = rawpayload()
  # println(post_data)
  shift = parse(Int, post_data)
  global octave = 0
  # println(octave)
end

route("/volume", method=POST) do
  post_data = rawpayload()
  # println(post_data)
  shift = parse(Int, post_data)
  global amp = shift / 10
  # println(amp)
end

route("/attack", method=POST) do
  post_data = rawpayload()
  # println(post_data)
  shift = parse(Int, post_data)
  global a = shift / 10
end
route("/hold", method=POST) do
  post_data = rawpayload()
  # println(post_data)
  shift = parse(Int, post_data)
  global h = shift / 10
end
route("/sustain", method=POST) do
  post_data = rawpayload()
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

route("/gain", method=POST) do
  post_data = rawpayload() # jsonpayload("data")
  # println(post_data)
  h = parse(Int, post_data)
  global gain = h
end

route("/cutoff", method=POST) do
  post_data = rawpayload() # jsonpayload("data")
  # println(post_data)
  h = parse(Int, post_data)
  global cutoff = h / 10
end

route("/ahdsrAct", method=POST) do
  post_data = rawpayload() # jsonpayload("data")
  global ahdsr *= -1
end

route("/distortAct", method=POST) do
  post_data = rawpayload() # jsonpayload("data")
  global distort *= -1
end

route("/vibAct", method=POST) do
  post_data = rawpayload() # jsonpayload("data")
  global vib *= -1
end

route("/tremAct", method=POST) do
  post_data = rawpayload() # jsonpayload("data")
  global trem *= -1
end

route("/resetVal", method=POST) do
  # Vibrato Lesson Variables
  global vibLesDep = 0
  global vibLesOF = 0

  # Tremolo and Vibrato
  global tremDepth = 0
  global tremOscillatingFreq = 0
  global trem = -1

  global vibOscillatingFreq = 0
  global vibDepth = 0
  global vib = -1

  # Misc variables
  global mode = 4 # waveform mode
  global octave = 0 # octave num
  global amp = 1 # amplitude
  global harmonicsNum = 1 # num of harmonics

  # AHDSR variables
  global a = 0
  global h = 1
  global d = 1
  global s = 1
  global r = 1
  global ahdsr = -1

  # Distortion Variables
  global gain = 0
  global cutoff = 0
end

# ------------------------------------

up()