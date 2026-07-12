(
SynthDef(\droneFM, {
	arg f1Freq=0.1, f2Freq=1.1, f3Freq=2.2, nFreq=440, m1Ratio=1, m2Ratio=2, m3Ratio=3,
	amp=0.1, dur=55, ampM=0.84 , pan=0;
	var sig, car1, mod1, car2, mod2, car3, mod3, env, index;
	index = LFNoise1.kr(0.2).range(2, 12);
	env = EnvGen.kr(Env.new([0, 0.70, 0.70, 0], [dur*0.333, dur*0.333, dur*0.333]), doneAction:2);
	mod1 = SinOsc.ar([nFreq * m1Ratio, nFreq+0.7 * m1Ratio], mul:nFreq * m1Ratio * index) * ampM;
	car1 = SinOsc.ar(f1Freq + mod1);
	mod2 = SinOsc.ar([nFreq * m2Ratio, nFreq+1.4 * m2Ratio], mul:nFreq * m2Ratio * index) * ampM;
	car2 = SinOsc.ar(f2Freq + mod2);
	mod3 = SinOsc.ar([nFreq * m3Ratio, nFreq+0.35 * m3Ratio], mul:nFreq * m3Ratio * index) * ampM;
	car3 = SinOsc.ar(f3Freq + mod3) * 0.4;
	sig = car1 + car2 + car3 * env * amp;
	sig = Pan2.ar(sig, pan);
	Out.ar(0, sig);
}).add;
)


// .-----.------.- melodies -.------.------.
// sad
(
// default clock set to 120 beats per minute (bpm)
TempoClock.default.tempo = 80/60;

Pbind(
	\scale, Scale.melodicMinor,
	\root, 1,
	\degree, Pseq([3, 7, 6, 5, 4, 3, 2, 3]),
	\octave, 5,
	\dur,    Pseq([1, 1, 3, 3, 1, 1, 2, 2])
).play
)

// cosmic

// default clock set to 120 beats per minute (bpm)
TempoClock.default.tempo = 100/60;
~r = NodeProxy.new;
~r.fadeTime = 2;
~r.source = \droneFM;
~r.play;

~r.set(\nFreq, 330);
~r.set(\nFreq, 220);

Pbind(
	\instrument, \droneFM,
	\scale, Scale.melodicMinor,
	\root, 1,
	\degree, Pseq([3, 7, 6, 5, 4, 3, 2, 3]),
	\octave, 5,
	\dur,    Pseq([1, 1, 3, 3, 1, 1, 2, 2])
).play
)