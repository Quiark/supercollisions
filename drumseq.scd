// --- step state (16 on/off) ---
~stepsByRow = Array.fill(7, { Array.fill(16, 0) }); // rows 1..8 (9 for safety)
// Grid rows are zero-based internally; each row contains 16 values of 0 or 1.
~sarpStepsByRow = Array.fill(7, { Array.fill(16, 0) });
~editSarp = false;

// MIDI root plus semitone offsets, indexed by sarp grid row.
~sarpRoot = 60;
~sarpNotes = [0, 2, 3, 5, 7, 10, 12];
~sarpFreqForRow = { |row| (~sarpRoot + ~sarpNotes.wrapAt(row)).midicps };

// optional: choose which drum this sequencer plays
~drums = [\kick, \snare, \hat, \hihat1, \kik3];

~touchOscHost = "10.0.8.34";
~touchOscPort = 7107;
~touchOsc = NetAddr(~touchOscHost, ~touchOscPort);

~pushTouchOscGrid = { |steps|
	steps.do { |rowSteps, row|
		rowSteps.do { |val, beat|
			~touchOsc.sendMsg(
				"/2/multitoggle/%/%".format(row + 1, beat + 1),
				val.asFloat
			);
		};
	};
};

~pushCurrentTouchOscGrid = {
	~pushTouchOscGrid.(~editSarp.if(~sarpStepsByRow, ~stepsByRow));
};

// --- tempo + clock ---
TempoClock.default.tempo = 120/60; // 120 bpm

// --- pattern: 16 steps, each step checks ~steps[i] ---
[\kseq, \sseq, \hseq, \hseq1, \k3seq].do { |name, row|
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

Pdef(\sarpseq,
	Pbind(
		\instrument, \ringarp,
		\dur, 1/4,
		\step, Pseries(0, 1, inf) % 16,
		\freq, Pfunc { |ev|
			var i = ev[\step].asInteger;
			var rows;

			rows = ~sarpStepsByRow.collect { |steps, row|
				(steps[i] == 1).if(row, nil)
			}.reject(_.isNil);

			rows.collect { |row| ~sarpFreqForRow.(row) }
		},
		\amp, 0.25,
		\type, Pfunc { |ev| (ev[\freq].size > 0).if(\note, \rest) }
	)
).play;
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
	var parts, row, beat, val, targetSteps;

	if(path == "/3/toggle5") {
		~editSarp = (msg[1].asFloat > 0.5);
		("sarp edit mode: %".format(~editSarp)).postln;
	};

	if(path.beginsWith("/2/multitoggle/")) {
		parts = path.split($/);
		parts.postln;

		// sanity check
		if(parts.size >= 5) {
			row  = parts[3].asInteger - 1;
			beat = parts[4].asInteger;
			val  = msg[1].asFloat; // usually 0.0/1.0

			if( beat.inclusivelyBetween(1, 16) ) {
				targetSteps = ~editSarp.if(~sarpStepsByRow, ~stepsByRow);
				targetSteps[row][beat-1] = (val > 0.5).if(1, 0);

				// debug print (comment out once confirmed)
				("% row:% beat:% -> % "
					.format(~editSarp.if("sarp", "drum"), row, beat, targetSteps[row][beat-1])).postln;
			};
		};
	};
};

//thisProcess.addOSCRecvFunc(~recvFunc);
