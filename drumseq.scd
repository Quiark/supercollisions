// --- step state (16 on/off) ---
~stepsByRow = Array.fill(7, { Array.fill(16, 0) }); // rows 1..8 (9 for safety)

// optional: choose which drum this sequencer plays
~drums = [\kick, \snare, \hat, \hihat1];

// --- tempo + clock ---
TempoClock.default.tempo = 120/60; // 120 bpm

// --- pattern: 16 steps, each step checks ~steps[i] ---
[\kseq, \sseq, \hseq, \hseq1].do { |name, row|
	var d = ~drums[row];
	Pdef(name,
		Pbind(
			\instrument, Pfunc { |ev| d },
			\dur, 1/4, // 16 steps per 4/4 bar (16th notes)
			\step, Pseries(0, 1, inf) % 16,
			\amp, Pfunc { |ev|
				var i = ev[\step].asInteger;
				// "i: %, row: %, steps: %".format(i, row, ~stepsByRow[row]).postln;
				(~stepsByRow[row][i] == 1).if(1.0, 0.0) // gate
			},
			// if amp is 0, make it a Rest so no synth is created:
			\type, Pfunc { |ev| (ev[\amp] > 0).if(\note, \rest) }
		)
	).play;
};
// OSCdef.trace(true);  // watch the post window while you press toggles



// Make sure SC is listening on that port (usually already is 57120; only needed if you changed it)
// thisProcess.openUDPPort(~oscInPort);

// ---- install low-level OSC receive function ----
// Keep a reference so you can remove it later.
~recvFunc = { |msg, time, replyAddr, recvPort|
	// msg is an Array: [addressString, arg1, arg2, ...]
	var path = msg[0].asString;

	// We only care about /2/multitoggle/<row>/<beat>
	// Fast parse: split by '/'
	// "/2/multitoggle/4/10" -> ["", "2", "multitoggle", "4", "10"]
	var parts, row, beat, val;


	if(path.beginsWith("/2/multitoggle/")) {
		parts = path.split($/);
		parts.postln;

		// sanity check
		if(parts.size >= 5) {
			row  = parts[3].asInteger - 1;
			beat = parts[4].asInteger;
			val  = msg[1].asFloat; // usually 0.0/1.0

			if( beat.inclusivelyBetween(1, 16) ) {
				~stepsByRow[row][beat-1] = (val > 0.5).if(1, 0);

				// debug print (comment out once confirmed)
				("row:% beat:% -> % "
					.format(row, beat, ~stepsByRow[row][beat-1])).postln;
			};
		};
	};
};

//thisProcess.addOSCRecvFunc(~recvFunc);
