
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

// from ai but sucks
SynthDef(\metallic_arp, {
    arg out = 0, freq = 440, amp = 0.2, gate = 1, pan = 0,
        atk = 0.002, dec = 0.12, sus = 0.0, rel = 0.1,
        ffreq = 2000, rq = 0.25, 
        modIndex = 3.5, modMult = 2.71; // Non-integer multipliers sound more metallic
        
    var carrier, modulator, modEnv, ampEnv, sig;

    // Snappy amp envelope for fast arpeggios
    ampEnv = EnvGen.kr(Env.adsr(atk, dec, sus, rel), gate, doneAction: 2);
    
    // Quick decay envelope to make the metallic ring "pluck" at the start of the note
    modEnv = EnvGen.kr(Env.adsr(0.001, 0.06, 0.1, 0.1), gate);

    // The modulator creates the metallic frequency
    modulator = SinOsc.ar(freq * modMult) * (modIndex * modEnv * 1000);

    // PMOsc introduces phase modulation (FM synthesis) using the modulator
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
	arg gate = 1, atk = 0.02, rls = 0.3, amp = 0.4, freq = 440, detune = 0.0045, fd = 1.1,
	delayTime = 0.25, delayDecay = 1.1, delayMix = 0.3;

	var env, del, dry, delayed, freeEnv;
	//var sig = SinOsc.ar(440 * EnvGen.kr(Env.perc(atk, rls)) * [0.98, 0.99, 1.01, 1.02]);
	//var sig = Klank.ar(`[[200, 315, 577, freq], nil, [1, 1, 1, 1]], Impulse.ar(2, 0, 0.4));
	var sig = Saw.ar(freq * 0.25 * ([-2, -1, 0, 1, 2] * detune + 1), 0.8);
	//sig = Mix.ar([sig, pad]);
	sig = LPF.ar(sig, freq * fd); 


	env = EnvGen.kr(Env.perc(atk, rls), gate);
	sig = Splay.ar(sig) * env;
	sig = NHHall.ar(sig, mix: 0.3, room: 0.9, damp: 0.5);
	/*
	// need to give more time for delay to play
	freeEnv = EnvGen.kr(
		Env([1, 1, 0], [rls + (delayTime * 1.5) + delayDecay, 0.02]),
		gate,
		doneAction: 2
	);

	dry = sig;

	delayed = CombC.ar(
		dry,
		maxdelaytime: 1.0,
		delaytime: [delayTime, delayTime],
		decaytime: delayDecay
	);

	//delayed = LPF.ar(delayed, 4500);
	//delayed = HPF.ar(delayed, 180);

	//sig = XFade2.ar(dry, delayed, 0.5);

	sig = dry + (delayed * 0.4);
	*/
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
		alpha = 0, beta = 0, cutoffMonitor = 0;
	var env, sig, lfo, resonanceLfo, cutoff, hasStarted, startupTimeout, safeFreq, detuneFactors, startTrigger;

	lpf = lpf.clip(0, 1);
	lpfq = lpfq.clip(0, 1);
	detune = detune.clip(0, 1);
	lfodep = lfodep.clip(0, 1);
	lforate = lforate.clip(0, 1);
	alpha = alpha.clip(0, 1);
	beta = beta.clip(0, 1);
	cutoffMonitor = cutoffMonitor.clip(0, 1);
	startTrigger = Impulse.kr(0);
	Poll.kr(startTrigger, gate, \stones_gate);
	Poll.kr(startTrigger, atk, \stones_atk);
	Poll.kr(startTrigger, rls, \stones_rls);
	Poll.kr(startTrigger, freq, \stones_freq);
	Poll.kr(startTrigger, amp, \stones_amp);
	Poll.kr(startTrigger, lpf, \stones_lpf);
	Poll.kr(startTrigger, lpfq, \stones_lpfq);
	Poll.kr(startTrigger, detune, \stones_detune);
	Poll.kr(startTrigger, lfodep, \stones_lfodep);
	Poll.kr(startTrigger, lforate, \stones_lforate);
	Poll.kr(startTrigger, alpha, \stones_alpha);
	Poll.kr(startTrigger, beta, \stones_beta);
	Poll.kr(startTrigger, cutoffMonitor, \stones_cutoffMonitor);
	detuneFactors = [ -2, -1, 0, 1, 2] * detune * 0.02 + 1;

	// handling fast playing so that synths get freed
	hasStarted = SetResetFF.kr(gate > 0, 0);
	startupTimeout = Line.kr(0, 1, 0.05);
	FreeSelf.kr(startupTimeout * (gate <= 0) * (hasStarted <= 0));
    safeFreq = freq.max(0.1);
	env = EnvGen.kr(Env.asr(atk.max(0.001), 1, rls.max(0.001)), gate, doneAction: 2);
	// env = EnvGen.kr(Env.new(levels: [0, 1, 0], times: [1, 1]), gate, doneAction: 2);
    lfo = EnvGen.kr(
		Env.perc(0.01, lforate.linexp(0, 1, 0.01, 2)),
		gate) * lfodep;
    resonanceLfo = EnvGen.kr(
		Env.perc(0.01, beta.linexp(0, 1, 0.01, 2)),
		gate) * alpha;
    sig = Saw.ar(safeFreq * detuneFactors, 0.8);
    cutoff = (safeFreq * lpf.linexp(0, 1, 0.5, 32) * (1 + lfo)).clip(20, 18000);
	SendReply.kr(Impulse.kr(20) * cutoffMonitor, '/stones/cutoff', cutoff);
    sig = RLPF.ar(sig, cutoff, (lpfq + resonanceLfo).clip(0, 1).linlin(0, 1, 1, 0.05));
    sig = Limiter.ar(LeakDC.ar(Splay.ar(sig * env * amp)), 0.9, 0.01);
	Out.ar(0, sig);
}).add;

// slowly oscillates, more suitable as pad rather than dynamic bass
SynthDef(\oscbass, {
	arg gate = 1, atk = 0.5, rls = 2, freq = 880, amp = 0.6, lfodep = 0, lforate = 0, lpf = 0.5, detune = 0.5;
	var env, sig, lpfenv, detuneFactors, filtLFO, cutoff, startTrigger;

	lfodep = lfodep.clip(0, 1);
	lforate = lforate.clip(0, 1);
	lpf = lpf.clip(0, 1);
	detune = detune.clip(0, 1);
	startTrigger = Impulse.kr(0);
	Poll.kr(startTrigger, gate, \oscbass_gate);
	Poll.kr(startTrigger, atk, \oscbass_atk);
	Poll.kr(startTrigger, rls, \oscbass_rls);
	Poll.kr(startTrigger, freq, \oscbass_freq);
	Poll.kr(startTrigger, amp, \oscbass_amp);
	Poll.kr(startTrigger, lfodep, \oscbass_lfodep);
	Poll.kr(startTrigger, lforate, \oscbass_lforat);
	Poll.kr(startTrigger, lpf, \oscbass_lpf);
	Poll.kr(startTrigger, detune, \oscbass_detune);
	detuneFactors = [  -0.7, 0, 1.1, 2.7 ] * detune * 0.02 + 1;

	filtLFO = SinOsc.kr(lforate.linexp(0, 1, 0.01, 10)) * lfodep;
	sig = SinOsc.ar(freq * detuneFactors , 0, 0.5) + LFTri.ar(freq  , 1.3, 0.5);
	env = EnvGen.kr(Env.asr(atk.max(0.001), 1, rls.max(0.001)), gate, doneAction: 2);

	cutoff = (freq * lpf.linexp(0, 1, 0.5, 32) * (1 + filtLFO)).clip(20, 18000);
	sig = RLPF.ar(sig, cutoff);

	SendReply.kr(Impulse.kr(20), '/stones/cutoff', cutoff);
    sig = Limiter.ar(LeakDC.ar(Splay.ar(sig * env * amp)), 0.9, 0.01);
	Out.ar(0, sig);
}).add;

SynthDef(\fmbass, {
	arg gate = 1, atk = 0.05, rls = 0.4, freq = 880, amp = 0.6, lfodep = 0, lforate = 0, lpf = 0.5, detune = 0.5,
		alpha = 0, beta = 0, lpfq = 0;
	var env, sig, lpfenv, detuneFactors, modLFO, cutoff, startTrigger, resonanceLfo;

	lfodep = lfodep.clip(0, 1);
	lforate = lforate.clip(0, 1);
	lpf = lpf.clip(0, 1);
	lpfq = lpfq.clip(0, 1);
	detune = detune.clip(0, 1);
	alpha = alpha.clip(0, 1);
	beta = beta.clip(0, 1);

	startTrigger = Impulse.kr(0);
	Poll.kr(startTrigger, gate, \oscbass_gate);
	Poll.kr(startTrigger, atk, \oscbass_atk);
	Poll.kr(startTrigger, rls, \oscbass_rls);
	Poll.kr(startTrigger, freq, \oscbass_freq);
	Poll.kr(startTrigger, amp, \oscbass_amp);
	Poll.kr(startTrigger, lfodep, \oscbass_lfodep);
	Poll.kr(startTrigger, lforate, \oscbass_lforat);
	Poll.kr(startTrigger, lpf, \oscbass_lpf);
	Poll.kr(startTrigger, detune, \oscbass_detune);
	detuneFactors = [  -2, -1, 0, 1, 2 ] * detune * 0.02 + 1;

    resonanceLfo = EnvGen.kr(
		Env.perc(0.01, beta.linexp(0, 1, 0.01, 2)),
		gate) * alpha;

	modLFO = SinOsc.kr(lforate.linexp(0, 1, 500, 4000)) * lfodep;
	modLFO.poll;
	sig = VarSaw.ar(freq * detuneFactors, iphase: modLFO);
	env = EnvGen.kr(Env.asr(atk.max(0.001), 1, rls.max(0.001)), gate, doneAction: 2);

	cutoff = (freq * lpf.linexp(0, 1, 0.5, 32)).clip(20, 18000);
	sig = RLPF.ar(sig, cutoff, (lpfq + resonanceLfo).clip(0, 1).linlin(0, 1, 1, 0.05));

    sig = Limiter.ar(LeakDC.ar(Splay.ar(sig * env * amp)), 0.9, 0.01);
	Out.ar(0, sig);
}).add;
