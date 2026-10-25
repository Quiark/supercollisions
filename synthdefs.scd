
SynthDef(\hihat1, {arg out = 0, amp = 0.5, att = 0.01, rel = 0.2, ffreq = 6000, pan = 0;
	var snd = WhiteNoise.ar(amp);
	var env = Env.perc(att, rel).kr(doneAction: 2);
	snd = HPF.ar(snd * env, ffreq);
	Out.ar(out, Pan2.ar(snd, pan));
},
metadata: (
	credit: "Bruno Tucunduva Ruviaro",
	category: \drums,
	tags: [\percussion, \hihat]
)
).add;

SynthDef(\kik3, {
	arg
	//Standard Values
	amp = 1, out = 0, pan = 0, freq = 66,
	//Amplitude Controls
	att = 0.01, dec = 0.1, decaylevel = 0.8, rel = 0.3, envCurve = -4,
	//Timbre Controls
	sweeptime = 0.08, sweepCurve = \exp, harmonic = 6, preamp = 3;

	var snd, env, fenv;

	env = Env.new(levels: [0, amp, decaylevel * amp, 0], times: [att, dec, rel], curve: envCurve).kr(doneAction: 2);

	fenv = Env.new(levels: [freq * harmonic, freq], times: [sweeptime], curve: sweepCurve).kr;

	snd = SinOsc.ar(freq: fenv, mul: preamp).distort;

    snd = Normalizer.ar(in: snd, level: env);

	Out.ar(out, Pan2.ar(snd, pan));
},
metadata: (
	credit: "Author Unknown",
	category: \drums,
	tags: [\unpitched, \bass]
	)
).add;

// ---- basic ones from gippity 5 -------
SynthDef(\kick, { |out=0, amp=0.9|
	var env = Env.perc(0.001, 0.18).ar(doneAction:2);
	var fenv = Env([80, 45], [0.03], curve: -6).ar;
	var sig = SinOsc.ar(fenv) * env;
	sig = sig + (BPF.ar(WhiteNoise.ar(0.15), 120, 0.5) * env * 0.5);
	Out.ar(out, (sig * amp).dup);
}).add;

SynthDef(\snare, { |out=0, amp=0.6|
	var env = Env.perc(0.001, 0.16).ar(doneAction:2);
	var noise = BPF.ar(WhiteNoise.ar, 1800, 0.8) * env;
	var tone = SinOsc.ar(200) * Env.perc(0.001, 0.10).ar;
	Out.ar(out, ((noise + tone) * amp).dup);
}).add;

SynthDef(\hat, { |out=0, amp=0.35|
	var env = Env.perc(0.001, 0.06).ar(doneAction:2);
	var sig = HPF.ar(WhiteNoise.ar, 7000) * env;
	Out.ar(out, (sig * amp).dup);
}).add;

// Tunable drum set: frequencies in Hz, envelope times in seconds, mixes in 0..1.
SynthDef(\basicKick, {
	arg out = 0, amp = 0.7, pan = 0, freq = 50, atk = 0.001, rls = 0.35,
		sweep = 4, sweepTime = 0.035, click = 0.15, clickFreq = 3500, drive = 1.5;
	var env, pitchEnv, clickEnv, sig;

	env = Env.perc(atk.max(0.0001), rls.max(0.001), curve: -6).ar(doneAction: 2);
	pitchEnv = Env([sweep.max(1), 1], [sweepTime.max(0.001)], curve: -6).ar;
	clickEnv = Env.perc(0.0001, 0.015).ar;
	sig = SinOsc.ar(freq.max(20) * pitchEnv) * env;
	sig = sig + (HPF.ar(WhiteNoise.ar, clickFreq.clip(20, 18000)) * clickEnv * env * click.clip(0, 1));
	sig = (sig * drive.max(1)).tanh;
	Out.ar(out, Pan2.ar(sig * amp, pan));
}).add;

SynthDef(\basicSnare, {
	arg out = 0, amp = 0.5, pan = 0, freq = 180, atk = 0.001, rls = 0.2,
		noiseMix = 0.7, ffreq = 2500, rq = 0.8, toneDecay = 0.6;
	var env, toneEnv, tone, noise, sig;

	env = Env.perc(atk.max(0.0001), rls.max(0.001), curve: -4).ar(doneAction: 2);
	toneEnv = Env.perc(atk.max(0.0001), rls.max(0.001) * toneDecay.clip(0.01, 1)).ar;
	tone = (SinOsc.ar(freq.max(20)) + (SinOsc.ar(freq.max(20) * 1.6) * 0.5)) * toneEnv;
	noise = BPF.ar(WhiteNoise.ar, ffreq.clip(20, 18000), rq.clip(0.05, 1)) * env;
	sig = (tone * (1 - noiseMix.clip(0, 1))) + (noise * noiseMix.clip(0, 1));
	Out.ar(out, Pan2.ar(sig * amp, pan));
}).add;

SynthDef(\basicHat, {
	arg out = 0, amp = 0.3, pan = 0, freq = 400, atk = 0.001, rls = 0.07,
		ffreq = 6500, rq = 0.6, metallic = 0.5;
	var env, metal, noise, sig;

	env = Env.perc(atk.max(0.0001), rls.max(0.001), curve: -6).ar(doneAction: 2);
	metal = Pulse.ar(freq.max(20) * [1, 1.342, 1.789, 2.123, 2.731, 3.117], 0.5).sum / 6;
	noise = WhiteNoise.ar;
	sig = (metal * metallic.clip(0, 1)) + (noise * (1 - metallic.clip(0, 1)));
	sig = BPF.ar(HPF.ar(sig, ffreq.clip(20, 18000)), (ffreq * 1.3).clip(20, 18000), rq.clip(0.05, 1));
	Out.ar(out, Pan2.ar(sig * env * amp, pan));
}).add;

// from ai but sucks
SynthDef(\metallic_arp, {
    arg out = 0, freq = 440, amp = 0.2, gate = 1, pan = 0,
        atk = 0.002, dec = 0.12, sus = 0.0, rel = 0.1,
        ffreq = 2000, rq = 0.25, 
        modIndex = 3.5, modMult = 2.71; // Non-integer multipliers sound more metallic
        
    var carrier, modEnv, ampEnv, sig;

    // Snappy amp envelope for fast arpeggios
    ampEnv = EnvGen.kr(Env.adsr(atk, dec, sus, rel), gate, doneAction: 2);
    
    // Quick decay envelope to make the metallic ring "pluck" at the start of the note
    modEnv = EnvGen.kr(Env.adsr(0.001, 0.06, 0.1, 0.1), gate);

    carrier = PMOsc.ar(freq, freq * modMult, modIndex * modEnv);
    
    // Mix the FM carrier with a detuned Saw for extra electronic body
    sig = Mix.new([carrier * 0.7, Saw.ar(freq * 1.005) * 0.3]);

    // Resonant low pass filter to shape the high-end ring
    sig = RLPF.ar(sig, ffreq, rq);

    // Apply envelope and output in stereo
    sig = Pan2.ar(sig * ampEnv * amp, pan);
    Out.ar(out, sig);
}).add;


// ---- mine -------
// arp inspired by KVNDRA
SynthDef(\tonea, { |out=0, amp=0.75, freq=440|
	var env = Env.perc(0.08, 0.26).ar(doneAction:2);
	var sig = HPF.ar(Saw.ar(freq), 7000) * env;
	Out.ar(out, (sig * amp).dup);
}).add;

SynthDef(\pupluck, {
    arg out = 0, freq = 110,  gate = 1,  detune = 0.003,  fd = 5, amp = 0.9;
    var sig, ampEnv;

	var detuneFactors = [ -2, -1, 0, 1 ,2] * detune + 1;

	ampEnv = EnvGen.kr(Env.perc(0.01, 1.0, 1), gate, doneAction: 2);
	sig = Pulse.ar(freq * detuneFactors, 0.4);
	//sig = sig + Saw.ar(freq * 2, 0.3);
	sig = sig + SinOsc.ar(freq / 2, 0.3);
	// sig = Ringz.ar(sig, freq * 4, MouseY.kr(0, 1));
	sig = LPF.ar(sig, (freq * fd));


	sig = Splay.ar(sig);
//	sig = NHHall.ar(sig);

	Out.ar(out, sig * ampEnv * amp);
}).add;



// TODO would be sick to have UI to tune detune (sic) while playing arps
// TODO idk maybe it has a high tone and a low saw (square?) as background at the same time
SynthDef(\sarp, {
	arg gate = 1, atk = 0.02, rls = 0.3, amp = 0.4, freq = 440, detune = 0.0045, fd = 1.1;

	var env, freeEnv;
	var sig = Saw.ar(freq * 0.25 * ([-2, -1, 0, 1, 2] * detune + 1), 0.8);
	sig = LPF.ar(sig, freq * fd); 


	env = EnvGen.kr(Env.perc(atk, rls), gate);
	sig = Splay.ar(sig) * env;
	sig = NHHall.ar(sig, mix: 0.3, room: 0.9, damp: 0.5);
	// TODO: problem: doesn't free itself
	freeEnv = env;
	Out.ar(0, sig * amp * freeEnv);
}).add;

SynthDef(\plink, {
	arg gate = 1, atk = 0.02, rls = 1.1, freq = 880, amp = 0.4;
	var env, sig;

	sig = Klank.ar(`[[freq * 0.71, freq, freq * 1.43, freq * 1.92], nil, [1, 1, 1, 1]], Impulse.ar(0.1, 0, 0.5));
	env = EnvGen.kr(Env.perc(atk, rls), gate, doneAction: 2);
	// TODO I want this applied on the whole thing
	// TODO don't forget to switch the env
	//sig = FreeVerb.ar(sig * env);
	sig = Splay.ar(sig * env * amp);
	Out.ar(0, sig);
}).add;


// percussive saw instrument
// designed to be tuned by the touchosc sliders
// maps all std params from 0 - 1
// TODO: LFO to raise Q at the end of the note, like a pluck?
// kvdrna-like arp: set lfodep and lfo rate to around 0.2
SynthDef(\stones, {
	arg gate = 1, atk = 0.02, rls = 1.1, freq = 880, amp = 0.6, 
		lpf = 0.5, lpfq = 0, detune = 0.5, lfodep = 0.0, lforate = 0.0, 
		alpha = 0, beta = 0, cutoffMonitor = 0, lfoshape = 1;
	var env, sig, cutLFO, resonanceLfo, cutoff, hasStarted, startupTimeout, safeFreq, detuneFactors ;

	lpf = lpf.clip(0, 1);
	lpfq = lpfq.clip(0, 1);
	detune = detune.clip(0, 1);
	lfodep = lfodep.clip(0, 1);
	lforate = lforate.clip(0, 1);
	alpha = alpha.clip(0, 1);
	beta = beta.clip(0, 1);
	cutoffMonitor = cutoffMonitor.clip(0, 1);
	detuneFactors = [ -2, -1, 0, 1, 2] * detune * 0.02 + 1;
	lfoshape = (lfoshape * 4).round.clip(0, 4);

	// handling fast playing so that synths get freed
	hasStarted = SetResetFF.kr(gate > 0, 0);
	startupTimeout = Line.kr(0, 1, 0.05);
	FreeSelf.kr(startupTimeout * (gate <= 0) * (hasStarted <= 0));
    safeFreq = freq.max(0.1);
	env = EnvGen.kr(Env.asr(atk.max(0.001), 1, rls.max(0.001)), gate, doneAction: 2);
	// env = EnvGen.kr(Env.new(levels: [0, 1, 0], times: [1, 1]), gate, doneAction: 2);
	// OSC /lfoshape: 0 pluck, 1 down, 2 up, 3 down-up, 4 up-down
	cutLFO = Select.kr(lfoshape, [
		EnvGen.kr(Env.perc(0.01, lforate), gate),
		EnvGen.kr(Env.new([1, 0], [lforate], 0.9), gate),
		EnvGen.kr(Env.new([0, 1], [lforate], 0.9), gate),
		EnvGen.kr(Env.new([1, 0, 1], [lforate / 2, lforate / 2], 0.9), gate),
		EnvGen.kr(Env.new([0, 1, 0], [lforate / 2, lforate / 2], 0.9), gate)
	]) * lfodep;
    resonanceLfo = EnvGen.kr(
		Env.perc(0.01, beta.linexp(0, 1, 0.01, 2)),
		gate) * alpha;
    sig = Saw.ar(safeFreq * detuneFactors, 0.8);
    cutoff = (safeFreq * lpf.linexp(0, 1, 0.5, 32) * (1 + cutLFO)).clip(20, 18000);
	SendReply.kr(Impulse.kr(20) * cutoffMonitor, '/stones/cutoff', cutoff);
    sig = RLPF.ar(sig, cutoff, (lpfq + resonanceLfo).clip(0, 1).linlin(0, 1, 1, 0.05));
    sig = Limiter.ar(LeakDC.ar(Splay.ar(sig * env * amp)), 0.9, 0.01);
	Out.ar(0, sig);
}).add;

SynthDef(\kbdAmbient, { |out=0, freq=440, gate=1, amp=0.15, bright=2000, rq=0.25, pan=0|
    var sig, env, cutoff;

    sig = (VarSaw.ar(freq * [1, 1.003], 0, 0.3, 0.12).sum)
        + (SinOsc.ar(freq * 0.5, 0, 0.06));
    env = EnvGen.kr(Env.asr(0.5, 1, 3.5, curve: -4), gate, doneAction: 2);
    cutoff = (bright * (0.7 + SinOsc.kr(0.08).range(0, 0.6))).clip(60, 12000);
    sig = RLPF.ar(sig, cutoff, rq);
    sig = Pan2.ar((sig * env * amp), pan);
    sig = sig + FreeVerb2.ar(sig[0], sig[1], mix: 0.25, room: 0.9, damp: 0.5);
    sig = HPF.ar(LeakDC.ar(sig), 20).tanh;
    Out.ar(out, sig);
}).add;

// slowly oscillates, more suitable as pad rather than dynamic bass
SynthDef(\oscbass, {
	arg gate = 1, atk = 0.5, rls = 2, freq = 880, amp = 0.6, lfodep = 0, lforate = 0, lpf = 0.5, detune = 0.5;
	var env, sig, detuneFactors, filtLFO, cutoff ;

	lfodep = lfodep.clip(0, 1);
	lforate = lforate.clip(0, 1);
	lpf = lpf.clip(0, 1);
	detune = detune.clip(0, 1);
	detuneFactors = [  -0.7, 0, 1.1, 2.7 ] * detune * 0.02 + 1;

	filtLFO = SinOsc.kr(lforate.linexp(0, 1, 0.01, 500)) * lfodep;
	sig = SinOsc.ar(freq * detuneFactors , 0, 0.5) + LFTri.ar(freq  , 1.3, 0.5);
	env = EnvGen.kr(Env.asr(atk.max(0.001), 1, rls.max(0.001)), gate, doneAction: 2);

	cutoff = (freq * lpf.linexp(0, 1, 0.5, 32) * (1 + filtLFO)).clip(20, 18000);
	sig = RLPF.ar(sig, cutoff);

	SendReply.kr(Impulse.kr(20), '/stones/cutoff', cutoff);
    sig = Limiter.ar(LeakDC.ar(Splay.ar(sig * env * amp)), 0.9, 0.01);
	Out.ar(0, sig);
}).add;

// more suitable for longer drone, 
// TODO remove attack
// TODO fix aliasing when multiple played together
SynthDef(\fmbass, {
	arg gate = 1, atk = 0.05, rls = 0.4, freq = 880, amp = 0.6, lfodep = 0, lforate = 0, lpf = 0.5, detune = 0.5,
		alpha = 0, beta = 0, lpfq = 0;
	var env, sig, detuneFactors, modLFO, cutoff, resonanceLfo;

	lfodep = lfodep.clip(0, 1);
	lforate = lforate.clip(0, 1);
	lpf = lpf.clip(0, 1);
	lpfq = lpfq.clip(0, 1);
	detune = detune.clip(0, 1);
	alpha = alpha.clip(0, 1);
	beta = beta.clip(0, 1);

	detuneFactors = [  -2, -1, 0, 1, 2 ] * detune * 0.02 + 1;

    resonanceLfo = EnvGen.kr(
		Env.perc(0.01, beta.linexp(0, 1, 0.01, 2)),
		gate) * alpha;

	modLFO = SinOsc.ar(freq * lforate.linexp(0, 1, 0.5, 8)) * lfodep;
	sig = VarSaw.ar(freq * detuneFactors);
	env = EnvGen.kr(Env.asr(atk.max(0.001), 1, rls.max(0.001)), gate, doneAction: 2);

	cutoff = ((1 + modLFO) * freq * lpf.linexp(0, 1, 0.5, 32)).clip(20, 18000);
	sig = RLPF.ar(sig, cutoff, (lpfq + resonanceLfo).clip(0, 1).linlin(0, 1, 1, 0.05));

    sig = Limiter.ar(LeakDC.ar(Splay.ar(sig * env * amp)), 0.9, 0.01);
	Out.ar(0, sig);
}).add;


SynthDef(\understatedReese, {
	arg out = 0, gate = 1, freq = 55, amp = 0.3, atk = 0.02, rls = 0.5,
		lpf = 0.4, lpfq = 0.25, detune = 0.2, lfodep = 0, lforate = 0,
		alpha = 0, beta = 0, cutoffMonitor = 0;
	var env, sig, cutoff, filterLfo, filterEnv, detuneAmount;

	env = EnvGen.kr(Env.asr(atk.max(0.001), 1, rls.max(0.001)), gate, doneAction: 2);
	detuneAmount = 0.003 + (detune.clip(0, 1) * 0.02);
	filterLfo = SinOsc.kr(lforate.clip(0, 1).linexp(0, 1, 0.01, 10)) * lfodep.clip(0, 1);
	filterEnv = EnvGen.kr(Env.perc(0.001, beta.clip(0, 1).linexp(0, 1, 0.01, 1)), gate) * alpha.clip(0, 1);
	sig = Saw.ar(freq * [1 - detuneAmount, 1 + detuneAmount], 0.35).sum;
	cutoff = (freq * lpf.clip(0, 1).linexp(0, 1, 3, 28) * (1 + filterLfo + filterEnv)).clip(30, 9000);
	sig = RLPF.ar(sig, cutoff, lpfq.clip(0, 1).linlin(0, 1, 1, 0.1));
	sig = LeakDC.ar(sig + SinOsc.ar(freq, mul: 0.15));
	SendReply.kr(Impulse.kr(20) * cutoffMonitor.clip(0, 1), '/stones/cutoff', cutoff);
	Out.ar(out, (sig * env * amp).dup);
}).add;

SynthDef(\woodyAcousticBass, {
	arg out = 0, gate = 1, freq = 55, amp = 0.35, atk = 0.003, rls = 0.45,
		lpf = 0.45, lpfq = 0.35, detune = 0, lfodep = 0, lforate = 0,
		alpha = 0.18, beta = 0.3, cutoffMonitor = 0;
	var env, pitchEnv, filterEnv, sig, cutoff, filterLfo, detuneAmount;

	env = EnvGen.kr(Env.asr(atk.max(0.001), 1, rls.max(0.001)), gate, doneAction: 2);
	pitchEnv = EnvGen.kr(Env([1.035, 1], [0.035], curve: -5), gate);
	filterEnv = EnvGen.kr(Env.perc(0.002, beta.clip(0, 1).linexp(0, 1, 0.01, 1)), gate) * (0.12 + alpha.clip(0, 1));
	filterLfo = SinOsc.kr(lforate.clip(0, 1).linexp(0, 1, 0.01, 10)) * lfodep.clip(0, 1);
	detuneAmount = detune.clip(0, 1) * 0.01;
	sig = LFTri.ar(freq * pitchEnv * [1 - detuneAmount, 1 + detuneAmount], mul: 0.35).sum;
	sig = sig + (BPF.ar(WhiteNoise.ar, freq * 3, 0.35) * filterEnv);
	cutoff = (freq * lpf.clip(0, 1).linexp(0, 1, 3, 18) * (1 + filterLfo + filterEnv)).clip(40, 10000);
	//sig = RLPF.ar(sig, cutoff, lpfq.clip(0, 1).linlin(0, 1, 1, 0.1));
	SendReply.kr(Impulse.kr(20) * cutoffMonitor.clip(0, 1), '/stones/cutoff', cutoff);
	Out.ar(out, (LeakDC.ar(sig) * env * amp).dup);
}).add;
