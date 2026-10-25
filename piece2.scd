(
// ---------- musical settings ----------
~scale = Scale.major;
~baseMidi = 36;


TempoClock.default.tempo = 120/60; // 120 bpm
~held = IdentityDictionary.new;
~heldDegrees = IdentityDictionary.new;
~heldSharpCapable = IdentityDictionary.new;
~heldChords = IdentityDictionary.new;
~sharpHeld = false;
~chordMode = 0;
~trackNames = [\arp1, \bass, \pad, \melody];
~trackDegrees = Array.fill(~trackNames.size, { List.new });
~trackIndices = Array.fill(~trackNames.size, 0);
~trackRoots = Array.fill(~trackNames.size, { ~baseMidi.mod(12) });
~selectedTrack = 0;
~recording = false;
~playing = false;
if(~trackPlayers.notNil) { ~trackPlayers.values.do(_.stop) };
~trackPlayers = IdentityDictionary.new;
~trackNoteParams = Array.fill(~trackNames.size, { |trackIndex|
    (lpf: 0.0, lpfq: 0, detune: 0.0, 
		lfodep: 0.0, lforate: 0.0, lfoshape: 1, 
		alpha: 0, beta: 0, amp: 0.83, rls: 1.1).putAll(~trackInstruments[trackIndex][\params])
});
~noteParams = ~trackNoteParams[~selectedTrack];
~cutoffMonitorNode = nil;

~dumpPreset = { |trackIndex|
    var params, code;
    trackIndex = trackIndex ? ~selectedTrack;
    params = ~trackNoteParams[trackIndex];
    code = "(\n~trackInstruments[%] = (synthDef: %, params: (\n%\n));\n~trackNoteParams[%].putAll(~trackInstruments[%][\\params]);\n)".format(
        trackIndex,
        ~trackInstruments[trackIndex][\synthDef].asCompileString,
        params.keys.asArray.sort.collect { |key|
            "    %: %".format(key.asString, params[key].asCompileString)
        }.join(",\n"),
        trackIndex,
        trackIndex
    );
    code.postln;
    code;
};

~degreeToMidi = { |deg|
    var degrees = ~scale.degrees;
    var octAdd = (deg div: degrees.size) * 12;
    ~baseMidi + degrees.wrapAt(deg) + octAdd;
};

~noteArgs = { |degree, sharp=false|
    var args = [\freq, (~degreeToMidi.(degree) + sharp.binaryValue).midicps, \amp, 0.9];
    ~noteParams.keysValuesDo { |key, value| args = args.add(key).add(value) };
    args;
};

~makeArpPattern = { |trackIndex|
    Pbind(
        \instrument, Pfunc { ~trackInstruments[trackIndex][\synthDef] },
        \degree, Pfunc {
            var degree;
            if(~trackDegrees[trackIndex].isEmpty) {
                \rest
            } {
                degree = ~trackDegrees[trackIndex].wrapAt(~trackIndices[trackIndex]);
                ~trackIndices[trackIndex] = ~trackIndices[trackIndex] + 1;
                degree;
            };
        },
        \scale, Pfunc { ~scale },
        \root, Pfunc { ~trackRoots[trackIndex] },
        \octave, ~baseMidi.div(12),
        \dur, 1/4,
        \legato, 0.75,
        \rls, Pfunc { ~trackNoteParams[trackIndex][\rls] },
        \amp, Pfunc { ~trackNoteParams[trackIndex][\amp] },
        \lpf, Pfunc { ~trackNoteParams[trackIndex][\lpf] },
        \lpfq, Pfunc { ~trackNoteParams[trackIndex][\lpfq] },
        \detune, Pfunc { ~trackNoteParams[trackIndex][\detune] },
        \lfodep, Pfunc { ~trackNoteParams[trackIndex][\lfodep] },
        \lforate, Pfunc { ~trackNoteParams[trackIndex][\lforate] },
        \lfoshape, Pfunc { ~trackNoteParams[trackIndex][\lfoshape] },
        \alpha, Pfunc { ~trackNoteParams[trackIndex][\alpha] },
        \beta, Pfunc { ~trackNoteParams[trackIndex][\beta] }
    );
};

~trackNames.do { |name, trackIndex| Pdef(name, ~makeArpPattern.(trackIndex)) };

~recordDegree = { |degree|
    if(~recording) { ~trackDegrees[~selectedTrack].add(degree) };
};

~setSharpForHeldNotes = {
    ~held.keysValuesDo { |id, syn|
        if(~heldSharpCapable[id]) {
            syn.set(\freq, (~degreeToMidi.(~heldDegrees[id]) + ~sharpHeld.binaryValue).midicps);
        };
    };
    ~heldChords.values.do { |chord|
        chord[\synths].do { |syn, index|
            syn.set(\freq, (~degreeToMidi.(chord[\degrees][index]) + ~sharpHeld.binaryValue).midicps);
        };
    };
};

~noteOn = { |id, degree, record=true, sharpCapable=false|
    var syn;
    if(degree.notNil and: { ~held[id].isNil }) {
        syn = Synth(~trackInstruments[~selectedTrack][\synthDef], ~noteArgs.(degree, sharpCapable and: { ~sharpHeld }));
        ~held[id] = syn;
        ~heldDegrees[id] = degree;
        ~heldSharpCapable[id] = sharpCapable;
        if(~cutoffMonitorNode.isNil) {
            ~cutoffMonitorNode = syn.nodeID;
            syn.set(\cutoffMonitor, 1);
        };
        if(record) { ~recordDegree.(degree) };
    };
};

~noteOff = { |id|
    var syn = ~held[id];
    if(syn.notNil) {
        if(syn.nodeID == ~cutoffMonitorNode) {
            ~cutoffMonitorNode = nil;
            syn.set(\cutoffMonitor, 0);
        };
        syn.set(\gate, 0);
        ~held.removeAt(id);
        ~heldDegrees.removeAt(id);
        ~heldSharpCapable.removeAt(id);
    };
};

~chordNoteOn = { |id, degree|
    var degrees, synths;
    if(~held[id].isNil and: { ~heldChords[id].isNil }) {
        degrees = if(~chordMode == 1) {
            [degree, degree + 2, degree + 4]
        } {
            [degree, degree + 2, degree + 4, degree + 6]
        };
        synths = degrees.collect { |chordDegree|
            Synth(~trackInstruments[~selectedTrack][\synthDef], ~noteArgs.(chordDegree, ~sharpHeld));
        };
        ~heldChords[id] = (synths: synths, degrees: degrees);
        if(~cutoffMonitorNode.isNil) {
            ~cutoffMonitorNode = synths[0].nodeID;
            synths[0].set(\cutoffMonitor, 1);
        };
        ~recordDegree.(degree);
    };
};

~chordNoteOff = { |id|
    var chord = ~heldChords[id];
    if(chord.notNil) {
        chord[\synths].do { |syn|
            if(syn.nodeID == ~cutoffMonitorNode) { ~cutoffMonitorNode = nil };
            syn.set(\gate, 0);
        };
        ~heldChords.removeAt(id);
    };
};

~panic = {
    ~held.values.do { |syn| syn.set(\gate, 0) };
    ~heldChords.values.do { |chord| chord[\synths].do { |syn| syn.set(\gate, 0) } };
    ~held.clear;
    ~heldDegrees.clear;
    ~heldSharpCapable.clear;
    ~heldChords.clear;
    ~cutoffMonitorNode = nil;
    "panic: all notes off".postln;
};

~toggleRecording = { ~recording = ~recording.not };

~clearSelectedTrack = {
    ~trackDegrees[~selectedTrack].clear;
    ~trackIndices[~selectedTrack] = 0;
};

~transposeSelectedTrack = { |degree|
    if(degree != \rest) {
        ~trackRoots[~selectedTrack] = ~degreeToMidi.(degree) - (~baseMidi.div(12) * 12);
    };
};

~selectTrack = { |trackIndex|
    ~selectedTrack = trackIndex;
    ~noteParams = ~trackNoteParams[trackIndex];
};

~startTransport = {
    if(~playing.not) {
        ~trackNames.do { |name|
            ~trackPlayers[name] = Pdef(name).play();
        };
        ~playing = true;
    };
};

~stopTransport = {
    ~trackPlayers.values.do(_.stop);
    ~trackPlayers.clear;
    ~playing = false;
};

if(~masterReverbDamp.isNil) { ~masterReverbDamp = 0.45 };
if(~masterReverb.notNil) { ~masterReverb.free };
~masterReverb = nil;
SynthDef(\masterReverb, { |out=0, mix=0.28, room=0.88, damp=0.45, amp=1|
    var input, signal, hall, decay;
    input = In.ar(out, 2);
    signal = switch(~reverbMode,
        \nhhall, {
            decay = damp.clip(0, 1);
            hall = NHHall.ar(
                input,
                rt60: room.linlin(0, 1, 0.1, 12) * decay.linexp(0, 1, 0.35, 1.5),
                hiFreq: decay.linexp(0, 1, 12000, 500),
                hiRatio: decay.linlin(0, 1, 1, 0.15)
            );
            XFade2.ar(input, hall, mix.linlin(0, 1, -1, 1));
        },
        \none, { input },
        { FreeVerb2.ar(input[0], input[1], mix, room, damp) }
    );
    signal = Limiter.ar(LeakDC.ar(signal) * amp, 0.9, 0.01);
    ReplaceOut.ar(out, signal);
}).add;
Routine({
    s.sync;
    ~masterReverb = Synth.tail(s, \masterReverb, [\damp, ~masterReverbDamp]);
}).play(AppClock);
)
