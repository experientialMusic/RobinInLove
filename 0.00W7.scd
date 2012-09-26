///////////////////// TO DO
//	- fade in all'inizio (fabio)
//	- ripetere lo stesso pattern con una certa probabilita' (fabio)
//	- non deve modulare in mezzo al tema oppure mettiamo i gradi nell'array del tema (fabio)
//	- gestione modulazione su proxVeryHigh (raul)
//	- variazione degli accompagnamenti (raul)

//	- intro evenutale di 2 o 4 battute (anche solo una mano), da farsi come oggetto
//	- metrica del pezzo
//	- aggiungere qualche accordo alterato

///////////////////// MODULAZIONI
//	- per cromatismo o per accordo comune
//	- V grado: 	a un certo punto quando capita l'accordo di I, V, VI, posso triggerare la modulazione al V grado e shifto
//				il primo accordo sara'il V della nuova scala, poi il primo e poi via seguendo
//				dopo 4, 6, 8 battute chiamo V-reverse = IV
//	- IV grado:	ho gia'la sensibile, capita un primo grado, decido di andare al IV, shifto e vado al primo, cui segue quarto (.75) o secondo (.25) e via dicendo
//				dopo 4, 6, 8 battute chiamo IV-reverse (o bis) = V
//	- IV grado bis: capita il 2grado vecchio (VI nuovo), shifto in scala ma non restto il counter, vado sul quarto
//	- IV, V grado poi si ritorna

///////////////////// MODULAZIONE (min/maj)
//	- I algorithm:	arrivo al IV-V grado e mi piazzo al I minore della stessa tonalita' (e viceversa) non e'di passaggio
//	- II algorithm:	al relativo VI grado, stesse note ma inserisco una sensibile (3 grado del vecchio), 
//					quando ci capita un secondo shifta, va al V del nuovo, si resetta il counter e va al primo del nuovo e il tema si rifara'subito cambiato di modo
//					torniamo indietro quando capita il primo, si shifa e si va al secondo della nuova, che va al V, reset counter e si va al primo

(

var accompanimentTask, melodyTask, startingTask;
var melodyStream, rhythmStream, accompanimentStream;
var melodyPattern, rhythmPattern, rhythmPatternBackup, rhythmPatternLength, currentChordDegree, chordNotes, nextChord, currentRhythmSet, rhythmSetCounter;
var mode, beatCounter, melodyDirection, rhythmMatrix, selectedChord, degree, degreeMaj, degreeHMin, harmony, harmonyHMin, harmonyMaj, startingRhythm, key, relativeKeyN;
var mod5, mod4, barsPreModCounter;
var themeMelody, themeChord, themeFlag, themeCounter, themeChordArray, themeMelodyArray, themeRhythmArray, themeRhythm, themeActive; // theme management
var o1, o2, o3, starta, fermoStart, melodyRange, varDissonance, dissonanceRhythm, dissonanceControl; // OSC
var proxVeryHigh, proxHigh, proxMed, proxLow; // proximity management
var soloLine, harmonicProgression, rhythmAdjustment, leftHand, delay, absolutePitch;
var proximity, volume, bpm, other, smooth, proxMod;
var volRangeSolo, volRangeAcc;
var randomNote; //variabili per proximity;
var rhythmRepete;


MIDIClient.init(0,1,2); // initialize the MIDI client:	
m = MIDIOut(0, MIDIClient.destinations.at(0).uid); // create a MIDI out connection:
m.connect(1);// and connect SC's first port to your device's port with for example QJackCtl


/////////////////////  OSC connections

o1 = OSCresponderNode(nil, "/distance", {
	|t, r, mesg|
	proximity = mesg[1];
	// tmp.postln;
	"proximity: ".post;
	proximity.postln;
	// volume = (proximity/3)+0.5;
	bpm = (proximity/2)+0.4;   
}).add;

o2 = OSCresponderNode(nil, "/speed", {
	|t, r, mesg|
	var tmp = mesg[1];
	volume = 0.5+(tmp/2);
	// bpm = (tmp*proximity)+0.5;
	"velocity: ".post;
	volume.postln;
}).add;

o3 = OSCresponderNode(nil, "/start", {
	|t, r, mesg|
	starta = mesg[1];
}).add;


/////////////////////  getting values

// volume = 0.5;		// tace finche'non entrano i soggetti 
proximity = 0.5;	// dissonanza, modo, ottava
bpm = 0.7;
rhythmRepete = 0;
fermoStart = 0;
// fino a 0.7 maggiore
// 0.4 - 0.7 minore
// 0/0.1 - 0.1/0.2 - 0.2/0.4 dissonanze


///////////////////// Mode | BPM

mode = "Maj"; // Maj
~tempo = 150*bpm;
melodyDirection = true; // false -> basso
leftHand = 0; // quarti=0, funereo=1, triste=2, medio=3 

"".postln;
"".postln;
"".postln;
key = ['A', 'B','C','C#','D','Eb','E','F','Gb','G','Ab'].choose.postln;
melodyRange = 0; // pitch range e'8 o 0
varDissonance = 0; // da 0 a 4
// themeRhythm = (rrand(0,1)+1)*4; // 4 o 8
themeRhythm = 4;
"Lunghezza tema: ".post;
themeRhythm.postln;
themeCounter = themeRhythm;


///////////////////// mapping degree to MIDI values

~notes = ['B', 'C', 'C#', 'D', 'Eb', 'E', 'F', 'F#', 'G', 'Ab', 'A', 'Bb', 'B'];
degreeMaj = [-1,0,2,4,5,7,9,11,12,14,16,17,19,21,23,24,26,28,29,31];
degreeHMin = [-1,0,2,3,5,7,8,11,12,14,15,17,19,20,23,24,26,27,29,31];


// probaility matrix of harmonic progression (from Piston W., Harmony, p.17)
~accMatrix =  [[0, 0.05, 0.07, 0.35, 0.35, 0.08, 0.1],
			[0.05, 0, 0.05, 0.05, 0.65, 0.20, 0],
			[0, 0.07, 0, 0.21, 0.07, 0.65, 0],
			[0.15, 0.15, 0.05, 0, 0.60, 0.05, 0],
			[0.64, 0.05, 0.05, 0.13, 0, 0.13, 0],
			[0.06, 0.35, 0.12, 0.12, 0.35, 0, 0],
			[1, 0, 0, 0, 0, 0, 0]];


harmonyMaj=[[1,3,5],[2,4,6],[3,5,7],[4,6,8],[5,7,9],[6,8,10],[7,9,11]];
harmonyHMin=[[1,3,5],[2,4,6],[3,5,7],[4,6,8],[5,7,9],[6,8,10],[7,9,11]];

case{mode == "HMin"}{harmony = harmonyHMin;degree = degreeHMin}
	{mode == "Maj"}{harmony = harmonyMaj;degree = degreeMaj};


///////////////////// patterns of length definition 
//	0-3 sono potenziali inizi - OK
//	0 va in liberta', piu'zeri ci sono piu'e facile che ci rimanga - SI
//	4 va + probabilmente su se stessa e con = prob su 2 e 3, se compare piu'volte aumenta la probabilita'che rimanga li  - NO
//	2, 3 vanno con la stessa prob uno sull'altro o sul 4 - OK
//	ogni 4 si va al finale - OK
//	5, 6 finali: 5 se si e'stati tanto in 1, 6 se si e'stati tanto negli altri - OK (circa)


rhythmSetCounter = [0,0,0,0,0,0,0];	// conteggio quante volte abbiamo pescato dai vari insiemi di lunghezze

rhythmMatrix = [
		[[2, 1, 1], [2, 1, 0.5, 0.5], [2, 0.5, 1, 0.5], [2, 0.5, 0.5, 1], [2, 0.5, 0.5, 0.5, 0.5], [4], [3, 0.5, 0.5], [3, 1], [1,1,2]], // inzio in liberta'

		[[1, 1, 1, 0.5, 0.5], [1, 1, 0.5, 1, 0.5], [1, 1, 0.5, 0.5, 1], [1, 1, 0.5, 0.5, 0.5, 0.5]], // primi due: quarti
		[[0.5, 0.5, 0.5, 0.5, 1, 0.5, 0.5], [0.5, 0.5, 0.5, 0.5, 0.5, 1, 0.5], [0.5, 0.5, 0.5, 0.5, 0.5, 0.5, 1], [0.5, 0.5, 0.5, 0.5, 0.5, 0.5, 0.5, 0.5]], // primi due: ottavi		
		[[1.5, 0.5, 1, 1], [1.5, 0.5, 1, 0.5, 0.5], [1.5, 0.5, 0.5, 1, 0.5], [1.5, 0.5, 0.5, 0.5, 1], [1.5, 0.5, 0.5, 0.5, 0.5, 0.5], [1.5, 0.5, 1.5, 0.5], [1.5, 0.5, 0.5, 1, 0.5]], // puntati 1.5-0.5 
		[[0.5, 1, 0.5,1, 1], [0.5, 1, 0.5,1, 0.5, 0.5], [0.5, 1, 0.5,0.5, 1, 0.5], [0.5, 1, 0.5,0.5, 0.5, 1], [0.5, 1, 0.5,0.5, 0.5, 0.5, 0.5], [0.5, 1, 0.5,1.5, 0.5], [0.5, 1, 0.5,0.5, 1, 0.5], [1, 1, 0.5, 1, 0.5],[0.5, 0.5, 0.5, 0.5, 0.5, 1, 0.5]], // sincope

		[[4],[2,2],[1,1,2]], // finale a
		[[1,0.5,0.5,2],[0.5,1,0.5,2],[0.5,0.5,0.5,0.5,2],[1,1,2]] // finale b
		];

dissonanceRhythm = [
	[[2, 0.3, 0.7, 1], [1, 1.1, 1.9, 0.5, 0.5], [0.1,1.1,2.2,0.6], [0.2, 0.8, 0.8, 1, 0.2, 0.7, 0.3], [1,0.2,1,0.8], [1, 1, 0.5, 0.4, 1.1], [1.5, 0.7, 0.3, 0.5, 0.3, 0.7]],
	[[0.8, 0.2, 0.3, 0.7, 0.6, 1.4], [1, 0.8, 3, 0.2], [0.5, 1, 0.3, 1.7, 0.5], [0.5, 1.4, 0.6, 0.5, 0.7, 0.3], [0.6, 1.4, 0.8, 1.2], [0.5, 0.8, 0.7, 1.2, 0.5, 0.3]],
	[[0.3, 0.4, 1.2, 0.6, 0.8, 0.7], [0.7, 3.3], [2.8, 1.2], [0.8, 0.3, 2, 0.7, 0.2], [2,1,1], [0.3, 1.8, 0.3, 0.2, 0.7, 0.7], [0.4, 3.1, 0.5], [1.2,1,0.2,1.1,0.5], [0.2, 0.3, 0.8, 0.5, 0.7, 0.5, 0.2, 0.8]]
	];


// matrice dinamica, dove si definiscono le probabilita' per i 7 insiemi di pattern ritmici
~rhythmProbabilityMatrix = [
						[1/5, 1/5, 1/5, 1/5, 1/5, 0, 0],
						[1/5, 1/5, 1/5, 1/5, 1/5, 0, 0],
						[0.04, 0.1, 0.33, 0.20, 0.33, 0, 0],
						[0.05, 0.2, 0.2, 0.35, 0.2, 0, 0],
						[0.05, 0.2, 0.2, 0.2, 0.35, 0, 0],
						[0.5, 0.3, 0.1, 0.1, 0, 0, 0],
						[0.05, 0.25, 0.35, 0.35, 0, 0, 0]
						];

///////////////////// function definition for soloLine
soloLine = { |x|

	//	scelta del pattern ritmico
	case{beatCounter == 1}{rhythmPattern=startingRhythm;}
		{beatCounter%4==0}{
			//	5, 6 finali: 5 se si e'stati tanto in 1, 6 se si e'stati tanto negli altri
			var tmp = [0,0,0,0,0,rhythmSetCounter[1],(rhythmSetCounter[2]+rhythmSetCounter[3]+rhythmSetCounter[4])/3];
			currentRhythmSet = tmp.maxIndex;
			rhythmPattern = rhythmMatrix[currentRhythmSet].choose;
			}
		{(beatCounter!=1).and(beatCounter%4!=0)}{
			currentRhythmSet = [0,1,2,3,4,5,6].wchoose(~rhythmProbabilityMatrix[currentRhythmSet]);
			rhythmPattern = rhythmMatrix.wchoose(~rhythmProbabilityMatrix[currentRhythmSet]).choose;
					};

	// dissono un po'	
	if(rrand(4,12) <= randomNote,{
		var tmp = floor(randomNote/3.1)-1; // 0, 1 o 2
		chordNotes[0] = (1 + rrand(1,(randomNote-1)))%12;
		chordNotes[0] = (3 + rrand(1,(randomNote-1)))%12;
		chordNotes[0] = (5 + rrand(1,(randomNote-1)))%12;
		rhythmPattern =  dissonanceRhythm[tmp].choose;
		},{}
	);		

	//	scelta delle note, pitch numera da 0 a 14
	melodyPattern = [];	
	for (0, (rhythmPattern.size-1), {arg i;melodyPattern= melodyPattern ++ '***';});
	melodyPattern[rrand(0,rhythmPattern.size-1)] = [chordNotes[rrand(0,2)], melodyRange+chordNotes[rrand(0,2)]].choose; // a caso in mezzo metto una nota dell'accordo

	melodyPattern[0]=chordNotes[rrand(0,2)];  //primo della battuta: uno dei gradi dell'accordo
	melodyPattern[rhythmPattern.size-1]=chordNotes[rrand(0,2)];  //ultimo della battuta: uno dei gradi dell'accordo
	melodyPattern[rhythmPattern.maxIndex] = chordNotes[0];

	if(rhythmPattern.size>1,{
		for (2, rhythmPattern.size-1,{
			arg i;
			if(rhythmPattern[i-1]!=0.5,{	melodyPattern[i-1] = chordNotes[rrand(0,2)];},{});
			if(melodyPattern[i-1]=='***',{
				if(melodyDirection,{
					if(melodyPattern[i-2]>19,{melodyPattern[i-1] = melodyPattern[i-2]-1},{melodyPattern[i-1] = melodyPattern[i-2]+1});
					},{
					if(melodyPattern[i-2]>0,{melodyPattern[i-1] = melodyPattern[i-2]-1},{melodyPattern[i-1] = melodyPattern[i-2]+1});
				})},
			{});
			if(melodyPattern[i-1]>19,{melodyPattern=chordNotes[rrand(0,2)];},{});
		});},{});

	// se c'e' dissonanza...
	if(varDissonance>0,{
		if(dissonanceRhythm.size>1,{
			for (2, dissonanceRhythm.size-1,{
				arg i;
				if(dissonanceRhythm[i-1]!=0.5,{ melodyPattern[i-1] = chordNotes[rrand(0,2)]+1;},{});
					if(melodyPattern[i-1]=='***',{
						if(melodyDirection,{
							if(melodyPattern[i-2]>19,{melodyPattern[i-1] = melodyPattern[i-2]-(rrand(0,4))},{melodyPattern[i-1] = melodyPattern[i-2] + (rrand(1,5))});
						},{
					if(melodyPattern[i-2]>0,{melodyPattern[i-1] = melodyPattern[i-2]-(rrand(0,7))},{melodyPattern[i-1] = melodyPattern[i-2]+(rrand(1,7))});
					})},
				{});
			if(melodyPattern[i-1]>19,{melodyPattern=chordNotes[rrand(0,2)]+1;},{});
			//melodyPattern.postln;
		});},{});	
	},{});	



	//	seleziona tema
	if((themeFlag<themeRhythm).and(beatCounter>16),{
		themeFlag = themeFlag + 1;
		themeMelodyArray = themeMelodyArray.add(melodyPattern);
		themeRhythmArray = themeRhythmArray.add(rhythmPattern);
		themeChordArray = themeChordArray.add(chordNotes);
		"costruendo il tema, battuta numero ".post;
		themeActive=true;
		themeFlag.postln;
		leftHand = 2;
		case{themeFlag-1 == 3}{leftHand = rrand(1,3);}
		    {themeFlag-1 == 6}{leftHand = 3};
		},{});

	rhythmAdjustment.(1);

};

rhythmAdjustment = { |x|
	if((currentRhythmSet==0).and(rhythmSetCounter[0]/beatCounter > 0.2),{
		~rhythmProbabilityMatrix[0][0] = ~rhythmProbabilityMatrix[0][0]+0.04;
		~rhythmProbabilityMatrix[0][1] = ~rhythmProbabilityMatrix[0][1]-0.01;
		~rhythmProbabilityMatrix[0][2] = ~rhythmProbabilityMatrix[0][2]-0.01;
		~rhythmProbabilityMatrix[0][3] = ~rhythmProbabilityMatrix[0][3]-0.01;
		~rhythmProbabilityMatrix[0][4] = ~rhythmProbabilityMatrix[0][4]-0.01;
		},{});
};


///////////////////// function definition for harmonicProgression
harmonicProgression = { |x|
	var current;
	1.do{|i|
		current = ~accMatrix[x].windex;
		currentChordDegree = current;
	};
	selectedChord = current;
};


///////////////////// setting variables
currentRhythmSet = rrand(0,3);
rhythmSetCounter[currentRhythmSet] = rhythmSetCounter[currentRhythmSet] + 1; // quante volte abbiamo pescato da quell'insieme
startingRhythm = rhythmMatrix[currentRhythmSet].choose;
beatCounter=0;
themeFlag=0;
themeMelodyArray=[];
themeChordArray=[];
themeRhythmArray=[];
themeActive = false;
randomNote=0;
proxMod = 6;
currentChordDegree = [0,3,4].choose;
selectedChord = harmony[currentChordDegree];
chordNotes = selectedChord;
~actualTones = harmony[currentChordDegree];
accompanimentStream = Pseq(selectedChord, inf).asStream; // accompaniment
relativeKeyN = ~notes.indexOf(key);
nextChord = nil;
barsPreModCounter=0;
mod5=0;
mod4=0;
proxVeryHigh = 0.7;
proxHigh = 0.5;
proxMed = 0.3;
proxLow = 0.2;

///////////////////// accompaniment fellow
accompanimentTask = Task({
	loop({
		beatCounter = beatCounter + 1;
		barsPreModCounter=barsPreModCounter+1;
		themeActive=false;
		if (beatCounter == 1, {currentChordDegree = [0,3,4].choose;},{});
		if (beatCounter%8 == 0, {currentChordDegree = 0},{});
		if (beatCounter%8 == 7, {currentChordDegree = 4},{});


//////////////////////// REAL TIME SELECTION
		~tempo = 150*bpm;
		if(proximity>proxHigh,{
			mode = "Maj";
			melodyDirection = true; // false -> basso
			proxMod=3;
			leftHand = 3;
		},{
			mode = "HMin";
			melodyDirection = false; // false -> basso
			proxMod = 7;
			leftHand = 2;
		});
		
		if(proximity<proxMed,{
			var tmp = proximity*(-20);
			leftHand = 1;
			randomNote = 12+tmp; // va da 12 al peggio a 4
		},{randomNote = 0});
		
		if(proximity<proxLow,{
			leftHand = 0;
		},{});

		// con una certa probabilita' ogni volta che peschi una nota la metti a caso: random(3,12)<=randomNote la metti a caso 

		case{mode == "HMin"}{harmony = harmonyHMin;degree = degreeHMin}
		{mode == "Maj"}{harmony = harmonyMaj;degree = degreeMaj};

		volRangeSolo = volume;
		volRangeAcc = volume;


	/// gestione modulazione

		if((barsPreModCounter>7).and(mod5==0).and(mod4==0).and(rrand(1,10)>proxMod).and((currentChordDegree == 0).or(currentChordDegree == 5)),{
			var prob;
			prob = [4,5].wchoose([0.5,0.5]);	// con uguale probabilita' modula in quarta o in quinta
			case{prob==5}{
					if(currentChordDegree == 0,{
						nextChord = 5;
					},{});
					if(currentChordDegree == 5,{
						nextChord = [5,4].wchoose([0.70,0.30]);
					},{});	
					"modulazione di quinta".postln;
					mod5=1;	
					degreeMaj = [6,7,9,11,12,14,16,18,19,21,23,24,26,28,30,32,34];
					degreeHMin = [6,7,9,10,12,14,15,18,19,21,22,24,26,27,30,32,34];
					// barsPreModCounter=0;
				}{prob==4}{ 					//vado al quarto grado
					if(currentChordDegree==0,{
						"modulazione di quarta".postln;
						mod4 = 1;
						degreeMaj = [4,5,7,9,10,12,14,16,17,19,21,22,24,26,28,29,32];
						degreeHMin = [4,5,7,8,10,12,13,16,17,19,20,22,24,25,28,29,32];
						//harmonyMaj=[[1,3,5],[2,4,6],[3,5,7],[4,6,8],[5,7,9],[6,8,10],[7,9,11]];
						//harmonyHMin=[[1,3,5],[2,4,6],[3,5,7],[4,6,8],[5,7,9],[6,8,10],[7,9,11]];
						currentChordDegree = 5;
						nextChord = 0;
						// barsPreModCounter = 0;
					},{});
				}
			},{});

		case{mod5==1}{mod5 = 2;	}
			{mod5>1}{mod5 = mod5+1;};

		case{mod4==1}{mod4 = 2;	currentChordDegree = [4,1,6].wchoose([0.18,0.75,0.7])}
			{mod4>1}{mod4 = mod4+1;};

		if((mod5>6).and(currentChordDegree==0),{	// condizione di terminazione della modulazione di quinta
			mod5 = 0;
			"modulazione di quinta terminata".postln;
			degreeMaj = [-1,0,2,4,5,7,9,11,12,14,16,17,19,21,23,24,26,28,29,31];
			degreeHMin = [-1,0,2,3,5,7,8,11,12,14,15,17,19,20,23,24,26,27,29,31];
			nextChord=0;
			barsPreModCounter=0;
			},{});

		case{nextChord==[0,3]}{currentChordDegree = 0; nextChord=3;}
			{nextChord==3}{currentChordDegree = [1,3].wchoose([0.25,0.75]); nextChord=nil;};

		if((mod4>6).and(currentChordDegree==0),{	// condizione di terminazione della modulazione di quarta
			mod4 = 0;
			"modulazione di quarta terminata".postln;
			degreeMaj = [-1,0,2,4,5,7,9,11,12,14,16,17,19,21,23,24,26,28,29,31];
			degreeHMin = [-1,0,2,3,5,7,8,11,12,14,15,17,19,20,23,24,26,27,29,31];
			nextChord=[0];
			barsPreModCounter=0;
		},{});	
		case{nextChord==[4,0]}{currentChordDegree = 4; nextChord=0;}
			{nextChord==0}{currentChordDegree = 0; nextChord=nil;};	
		chordNotes = harmony[currentChordDegree];

		~actualTones = chordNotes;
		soloLine.(1);
		if ((rrand(1,3) + rhythmRepete) > 2,{ 
			rhythmPattern = rhythmPatternBackup; 
			"ripeto".postln;
			rhythmRepete = rhythmRepete + 1;
			if(rhythmRepete==3,{rhythmRepete = 0;}
			,{});
		},{}); // con qualche probabilita'ripesco
		
		
		// riseleziono il tema a caso
		if ((proximity>proxMed).and(themeFlag==themeRhythm).and(rrand(0,6)>4),{
			// entro solo se il tema e'stato costruito
			if (themeCounter==themeRhythm,{
				"THEME SELECTED".postln;
				themeCounter = 0;
				themeActive=true;
				},{});
			},{});

		if((proximity>proxVeryHigh).and(themeFlag==themeRhythm),{
			if (themeCounter==themeRhythm,{
				"THEME SELECTED".postln;
				themeCounter = 0;
				},{});
		},{});

		if ((themeCounter<themeRhythm),{
			themeActive=true;
			"Theme bar number ".post;
			(themeCounter+1).postln;
			melodyPattern = themeMelodyArray[themeCounter];
			chordNotes = themeChordArray[themeCounter];
			leftHand = 0;
			case{themeCounter == 3}{leftHand = rrand(1,3);}
			    {themeCounter == 6}{leftHand = 3}
			    {themeCounter == 7}{leftHand = rrand(1,3);};
			themeCounter = themeCounter +1;
			},{});
		"".postln;
		beatCounter.post;

		"  Degree:".post; (currentChordDegree+1).post;
		"  Chord:".post; ~notes[(degree[chordNotes]+relativeKeyN)%12].post;
		"  Rhythm:".post; rhythmPattern.post;

		rhythmStream = Pseq(rhythmPattern, inf).asStream;
		melodyStream = Pseq(melodyPattern, inf).asStream;
		rhythmPatternLength = rhythmPattern.size.postln;
		rhythmPatternBackup = rhythmPattern;
		// actual pitch to be played (pretend we are in Maj Scale):
		// 60 is the central C, we just take the degree of the chosen pattern in the mapped mode
		case{leftHand==0}{
				m.noteOn(0, 47+relativeKeyN+degree[chordNotes[0]], 120*volRangeAcc); m.noteOn(16, (47+relativeKeyN+degree[chordNotes[1]]), 100*volRangeAcc);  m.noteOn(16, (47+relativeKeyN+degree[chordNotes[2]]), 100*volRangeAcc);
				(4*(60/~tempo)).wait;
				m.noteOff(0, 47+relativeKeyN+degree[chordNotes[0]], 120*volRangeAcc); m.noteOff(16, (47+relativeKeyN+degree[chordNotes[1]]), 100*volRangeAcc); m.noteOff(16, (47+relativeKeyN+degree[chordNotes[2]]), 100*volRangeAcc);

			}

			{leftHand==1}{
				m.noteOn(0, 35+relativeKeyN+degree[chordNotes[0]], 120*volRangeAcc);
				(3*(60/~tempo)).wait;

				2.do{ |i|
					m.noteOn(0, 47+relativeKeyN+degree[chordNotes[i]], 80*volRangeAcc);
					(4*(60/(8*~tempo))).wait;
					m.noteOff(0, 47+relativeKeyN+degree[chordNotes[i]], 80*volRangeAcc);
				};

				m.noteOff(0, 35+relativeKeyN+degree[chordNotes[0]], 120*volRangeAcc);
			}

			{leftHand==2}{
				m.noteOn(0, 35+relativeKeyN+degree[chordNotes[0]], 120*volRangeAcc);
				(2*(60/~tempo)).wait;
				2.do{ |i|
					m.noteOn(0, 47+relativeKeyN+degree[chordNotes[i]], 80*volRangeAcc);
					(4*(60/(8*~tempo))).wait;
					m.noteOff(0, 47+relativeKeyN+degree[chordNotes[i]], 80*volRangeAcc);
				};
				2.do{ |i|
					m.noteOn(0, 47+relativeKeyN+degree[chordNotes[i]], 80*volRangeAcc);
					(4*(60/(8*~tempo))).wait;
					m.noteOff(0, 47+relativeKeyN+degree[chordNotes[i]], 80*volRangeAcc);
				};
				m.noteOff(0, 35+relativeKeyN+degree[chordNotes[0]], 120*volRangeAcc);
			}

			{leftHand==3}{
				m.noteOn(0, 35+relativeKeyN+degree[chordNotes[0]], 120*volRangeAcc);
				2.do{ |i|
					m.noteOn(0, 47+relativeKeyN+degree[chordNotes[i]], 80*volRangeAcc);
					(4*(60/(8*~tempo))).wait;
					m.noteOff(0, 47+relativeKeyN+degree[chordNotes[i]], 80*volRangeAcc);
				};
				2.do{ |i|
					m.noteOn(0, 47+relativeKeyN+degree[chordNotes[i]], 80*volRangeAcc);
					(4*(60/(8*~tempo))).wait;
					m.noteOff(0, 47+relativeKeyN+degree[chordNotes[i]], 80*volRangeAcc);
				};
				if ((rrand(0,1) > 0).and(0 == 0),{
					2.do{ |i|
						m.noteOn(0, 47+relativeKeyN+degree[chordNotes[i]+1], 80*volRangeAcc);
						(4*(60/(8*~tempo))).wait;
						m.noteOff(0, 47+relativeKeyN+degree[chordNotes[i]+1], 80*volRangeAcc);
					};
				},{
					2.do{ |i|
						m.noteOn(0, 47+relativeKeyN+degree[chordNotes[i]], 80*volRangeAcc);
						(4*(60/(8*~tempo))).wait;
						m.noteOff(0, 47+relativeKeyN+degree[chordNotes[i]], 80*volRangeAcc);
					};
				});
				2.do{ |i|
					m.noteOn(0, 47+relativeKeyN+degree[chordNotes[i]], 80*volRangeAcc);
					(4*(60/(8*~tempo))).wait;
					m.noteOff(0, 47+relativeKeyN+degree[chordNotes[i]], 80*volRangeAcc);
				};

				m.noteOff(0, 35+relativeKeyN+degree[chordNotes[0]], 120*volRangeAcc);
			};

		harmonicProgression.(currentChordDegree);
		rhythmSetCounter[currentRhythmSet] = rhythmSetCounter[currentRhythmSet] + 1;
		"".postln;

	});
});


///////////////////// solo fellow
melodyTask = Task({
	loop({arg tmpVel;
		var tmpPitch = melodyStream.value;
		var tmpLength = rhythmStream.value; // controllo sui BPM
		var voiceTranspose;
//		"".postln;
//		tmpLength.post;
		tmpLength = (60/~tempo)*tmpLength;
		rhythmPatternLength = (rhythmPatternLength-1).post;
		" ".post;
		// actual pitch to be played (pretend we are in Maj Scale):
		// 60 is the central C, we just take the degree of the chosen pattern in the mapped mode
		absolutePitch = 59+relativeKeyN+degree[tmpPitch];
		voiceTranspose = 59+relativeKeyN+degree[tmpPitch+2]; // la seconda voce, leggermente sfasata, va sopra di un intervallo di seconda nei temi


		if(rrand(4,12) <= randomNote,{
			absolutePitch = absolutePitch + rrand(-1*randomNote,1*randomNote)},{}
		);

		tmpVel = rrand(90,120)*volRangeSolo;

		if(rhythmPatternLength>=0,{
			delay = 0.03;
			m.noteOn(1, absolutePitch, tmpVel);
			delay.wait;
			if(themeActive,{m.noteOn(2, voiceTranspose, tmpVel)},{m.noteOn(2, absolutePitch, tmpVel)});
			//m.noteOn(2, absolutePitch, tmpVel);
			(tmpLength-delay).wait;
			m.noteOff(1, absolutePitch, tmpVel);
			//0.01.wait;
			if(themeActive,{m.noteOff(2, voiceTranspose, tmpVel)},{m.noteOff(2, absolutePitch, tmpVel)});
			//m.noteOff(2, absolutePitch, tmpVel);
		},{
			wait(0.01);
		});
	});
});

startingTask = Task({
	loop({
		if((starta==1).and(fermoStart==0),{
			"start: ".post;
			starta.postln;
			accompanimentTask.start;
			melodyTask.start;
			starta = 0;
			fermoStart = 1;
		},{});
		wait(0.1);
	});
});

soloLine.(1);
rhythmStream = Pseq(rhythmPattern, inf).asStream;
melodyStream = Pseq(melodyPattern, inf).asStream;
startingTask.start;

)
