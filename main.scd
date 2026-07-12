~projectDir = thisProcess.nowExecutingPath.dirname;

s.waitForBoot({
    // Load synthdefs (executes that file in this interpreter)
    (~projectDir +/+ "synthdefs.scd").load;

	(~projectDir +/+ "drumseq.scd").load;
	 (~projectDir +/+ "kbd.scd").load;
	OSCdef.trace(true);
	OSCdef.trace(false);


});


(
// run this once only
thisProcess.addOSCRecvFunc({ |msg, time, replyAddr, recvPort|
	~recvFunc.(msg, time, replyAddr, recvPort);
});

)

OSCdef.all.keys.postln;

Synth(\metallic_arp, [atk: 0.3, freq: 380, rel: 0.9, modIndex: 3.5, modMult: 1.231]);

Env.adr
SCLOrkSynths.gui;


// NOTE: ok right now by accident it's kind of a nice tone
(
SynthDef(\arp, {
    arg out = 0, freq = 110,  gate = 1,  detune = 0.003,  fd = 5;
    var sig, ampEnv;

	var detuneFactors = [ -2, -1, 0, 1 ,2] * detune + 1;

	ampEnv = EnvGen.kr(Env.perc(0.01, 1.0, 1), gate, doneAction: 2);
	sig = Pulse.ar(freq * detuneFactors, 0.4);
	sig = sig + Saw.ar(freq * 2, 0.3);
	sig = sig + SinOsc.ar(freq / 2, 0.3);
	// sig = Ringz.ar(sig, freq * 4, MouseY.kr(0, 1));
	sig = LPF.ar(sig, (freq * fd).poll);


	sig = Splay.ar(sig);
//	sig = NHHall.ar(sig);

	Out.ar(out, sig * ampEnv);
}).play;
)