helpers = require '../../helpers'
helpers.setupBrowserEnvironment()

GeneticEngine = requirejs 'md2d/models/engine/genetic-engine'
Model         = requirejs 'md2d/models/modeler'

describe "GeneticEngine", ->
  describe "[basic tests of the class]", ->
    describe "GeneticEngine constructor", ->
      it "should exist", ->
        should.exist GeneticEngine

      it "should act as a constructor", ->
        geneticEngine = new GeneticEngine(new Model {})
        should.exist geneticEngine

    describe "GeneticEngine instance", ->
      model = null
      geneticEngine = null
      mock =
        changeListener: ->
        transitionListener: ->
          # Call transitionEdned after each transition! It's required, as
          # geneticEngine will enqueue new transitions as long as some
          # transition is thought to be in progress.
          geneticEngine.transitionEnded()

      before ->
        # Note that we have to set DNA to any value to ensure that model
        # dimensions will be set correctly. We should refactor xmin, ymin,
        # xmax, ymax + width and height options and don't  treat them as
        # immutable (only viewport width and height should be immutable).
        model = new Model {DNA: "ATCG"}
        geneticEngine = model.geneticEngine()

      beforeEach ->
        sinon.spy mock, "changeListener"
        sinon.spy mock, "transitionListener"
        geneticEngine.on "change", mock.changeListener
        geneticEngine.on "transition", mock.transitionListener

      afterEach ->
        mock.changeListener.restore()
        mock.transitionListener.restore()

      checkViewModel = (array, sequence) ->
        for nucleo, i in array
          nucleo.idx.should.eql i
          nucleo.type.should.eql sequence[i]

      it "should automatically change lower case DNA string to upper case", ->
          model.set "DNA", "atgc"
          model.get("DNA").should.eql "ATGC"
          model.set "DNA", "aTGc"
          model.get("DNA").should.eql "ATGC"
          model.set "DNA", "AtgC"
          model.get("DNA").should.eql "ATGC"
          model.set "DNA", "aTgC"
          model.get("DNA").should.eql "ATGC"

      it "should reset geneticEngineState to translation:0 if DNA is changed during translation:x steps", ->
          model.set "DNA", "ATCG"
          model.set "geneticEngineState", "translation:0"
          geneticEngine.transitionToNextState()
          model.get("geneticEngineState").should.eql "translation:1"

          model.set "DNA", "ATC"
          model.get("geneticEngineState").should.eql "translation:0"

      it "should calculate view arrays and dispatch appropriate event after setting DNA", ->
        mock.changeListener.callCount.should.eql 0
        model.set "geneticEngineState", "dna"
        model.set "DNA", "ATGC"
        checkViewModel geneticEngine.viewModel.DNA, "ATGC"
        checkViewModel geneticEngine.viewModel.DNAComp, "TACG"
        checkViewModel geneticEngine.viewModel.mRNA, ""
        mock.changeListener.callCount.should.eql 2
        mock.transitionListener.callCount.should.eql 0

      it "should calculate mRNA when state is set to 'transcription-end' or 'translation'", ->
        model.set "geneticEngineState", "transcription-end"
        checkViewModel geneticEngine.viewModel.mRNA, "AUGC"
        mock.changeListener.callCount.should.eql 1
        mock.transitionListener.callCount.should.eql 0

      it "should perform single step of DNA to mRNA transcription", ->
        model.set "geneticEngineState", "dna"
        checkViewModel geneticEngine.viewModel.mRNA, ""
        geneticEngine.transcribeStep()
        checkViewModel geneticEngine.viewModel.mRNA, ""   # DNA separated, mRNA prepared for transcription
        geneticEngine.transcribeStep()
        checkViewModel geneticEngine.viewModel.mRNA, "A"
        geneticEngine.transcribeStep("A") # Wrong, "U" is expected!
        checkViewModel geneticEngine.viewModel.mRNA, "A"  # Nothing happens, mRNA is still the same.
        geneticEngine.transcribeStep("U") # This time expected nucleotide is correct,
        checkViewModel geneticEngine.viewModel.mRNA, "AU" # so it's added to mRNA.

      it "should transcribe mRNA from DNA and dispatch appropriate events", ->
        model.set "geneticEngineState", "dna"
        model.set {DNA: "ATGC"}
        geneticEngine.transitionTo("transcription-end")
        mock.transitionListener.callCount.should.eql 5 # separation + 4 x transcription

        checkViewModel geneticEngine.viewModel.mRNA, "AUGC"

      it "shouldn't allow setting geneticEngineState to translation:x, where x > 0", ->
        model.set "geneticEngineState", "translation:15"
        # Expect fallback state: translation:0.
        model.get("geneticEngineState").should.eql "translation:0"

      it "should allow jumping to the next state", ->
        model.set "DNA", "ATGC" # so transcription and translation will be short
        model.set "geneticEngineState", "intro-cells"
        geneticEngine.jumpToNextState()
        model.get("geneticEngineState").should.eql "intro-zoom1"
        geneticEngine.jumpToNextState()
        model.get("geneticEngineState").should.eql "intro-zoom2"
        geneticEngine.jumpToNextState()
        model.get("geneticEngineState").should.eql "intro-zoom3"
        geneticEngine.jumpToNextState()
        model.get("geneticEngineState").should.eql "intro-polymerase"
        geneticEngine.jumpToNextState()
        model.get("geneticEngineState").should.eql "dna"
        geneticEngine.jumpToNextState()
        model.get("geneticEngineState").should.eql "transcription:0"
        geneticEngine.jumpToNextState()
        model.get("geneticEngineState").should.eql "transcription:1"
        geneticEngine.jumpToNextState()
        model.get("geneticEngineState").should.eql "transcription:2"
        geneticEngine.jumpToNextState()
        model.get("geneticEngineState").should.eql "transcription:3"
        geneticEngine.jumpToNextState()
        model.get("geneticEngineState").should.eql "transcription-end"
        geneticEngine.jumpToNextState()
        model.get("geneticEngineState").should.eql "after-transcription"
        geneticEngine.jumpToNextState()
        model.get("geneticEngineState").should.eql "before-translation"
        geneticEngine.jumpToNextState()
        model.get("geneticEngineState").should.eql "translation:0"
        geneticEngine.jumpToNextState()
        model.get("geneticEngineState").should.eql "translation-end"

      it "should allow jumping to the previous state", ->
        model.get("geneticEngineState").should.eql "translation-end"

        geneticEngine.jumpToPrevState();
        model.get("geneticEngineState").should.eql "translation:0"
        geneticEngine.jumpToPrevState();
        model.get("geneticEngineState").should.eql "before-translation"
        geneticEngine.jumpToPrevState();
        model.get("geneticEngineState").should.eql "after-transcription"
        geneticEngine.jumpToPrevState();
        model.get("geneticEngineState").should.eql "transcription-end"
        geneticEngine.jumpToPrevState();
        model.get("geneticEngineState").should.eql "transcription:3"
        geneticEngine.jumpToPrevState();
        model.get("geneticEngineState").should.eql "transcription:2"
        geneticEngine.jumpToPrevState();
        model.get("geneticEngineState").should.eql "transcription:1"
        geneticEngine.jumpToPrevState();
        model.get("geneticEngineState").should.eql "transcription:0"
        geneticEngine.jumpToPrevState();
        model.get("geneticEngineState").should.eql "dna"
        geneticEngine.jumpToPrevState();
        model.get("geneticEngineState").should.eql "intro-polymerase"
        geneticEngine.jumpToPrevState();
        model.get("geneticEngineState").should.eql "intro-zoom3"
        geneticEngine.jumpToPrevState();
        model.get("geneticEngineState").should.eql "intro-zoom2"
        geneticEngine.jumpToPrevState();
        model.get("geneticEngineState").should.eql "intro-zoom1"
        geneticEngine.jumpToPrevState();
        model.get("geneticEngineState").should.eql "intro-cells"
        # make sure that this won't break anything:
        geneticEngine.jumpToPrevState();
        model.get("geneticEngineState").should.eql "intro-cells"

      it "should let user perform substitution mutation", ->
        model.set "geneticEngineState", "transcription:0"
        model.set "DNA", "ATGC"

        geneticEngine.mutate 0, "C"
        model.get("DNA").should.eql "CTGC"
        geneticEngine.mutate 1, "G"
        geneticEngine.mutate 2, "T"
        geneticEngine.mutate 3, "A"
        model.get("DNA").should.eql "CGTA"
        # Mutation performed on DNA complement strand.
        geneticEngine.mutate 0, "A", true
        model.get("DNA").should.eql "TGTA"
        # State should remain the same.
        model.get("geneticEngineState").should.eql "transcription:0"

      it "should let user perform insertion mutation", ->
        model.set "DNA", "ATGC"

        geneticEngine.insert 0, "A"
        model.get("DNA").should.eql "AATGC"
        geneticEngine.insert 4, "C"
        model.get("DNA").should.eql "AATGCC"
        # Mutation performed on DNA complement strand.
        geneticEngine.insert 0, "T", true
        model.get("DNA").should.eql "AAATGCC"
        # State should remain the same.
        model.get("geneticEngineState").should.eql "transcription:0"

      it "should let user perform insertion mutation in the middle of transcription", ->
        model.set "DNA", "ATGC"
        model.set "geneticEngineState", "transcription:3" # ATG are transcribed

        # Insert between transcribed nucleotides.
        geneticEngine.insert 0, "A"
        model.get("DNA").should.eql "AATGC"
        # Step should be increased to make sure that now 4 nucleotides are transcribed.
        model.get("geneticEngineState").should.eql "transcription:4"
        geneticEngine.insert 3, "G"
        model.get("DNA").should.eql "AATGGC"
        model.get("geneticEngineState").should.eql "transcription:5"

        # Insert after transcribed nucleotides.
        geneticEngine.insert 5, "C"
        model.get("DNA").should.eql "AATGGCC"
        # State without changes.
        model.get("geneticEngineState").should.eql "transcription:5"

      it "should let user perform deletion mutation", ->
        model.set "geneticEngineState", "transcription:0"
        model.set "DNA", "ATGC"

        geneticEngine.delete 0
        model.get("DNA").should.eql "TGC"
        geneticEngine.delete 2
        model.get("DNA").should.eql "TG"
        geneticEngine.delete 1
        model.get("DNA").should.eql "T"
        geneticEngine.delete 0
        model.get("DNA").should.eql ""
        # State should remain the same.
        model.get("geneticEngineState").should.eql "transcription:0"

      it "should let user perform deletion mutation in the middle of transcription", ->
        model.set "DNA", "ATGC"
        model.set "geneticEngineState", "transcription:3" # ATG are transcribed

        # Insert delete one of the transcribed nucleotides.
        geneticEngine.delete 0
        model.get("DNA").should.eql "TGC"
        # Step should be decreased to make sure that now only 2 nucleotides are transcribed.
        model.get("geneticEngineState").should.eql "transcription:2"
        geneticEngine.delete 1
        model.get("DNA").should.eql "TC"
        model.get("geneticEngineState").should.eql "transcription:1"

        # Delete nucleotide which is not transcribed at the moment.
        geneticEngine.delete 1
        model.get("DNA").should.eql "T"
        # State without changes.
        model.get("geneticEngineState").should.eql "transcription:1"


      it "should provide state() helper methods", ->
        model.set "geneticEngineState", "transcription-end"
        state = geneticEngine.state()
        state.name.should.eql "transcription-end"
        isNaN(state.step).should.be.true

        model.set "geneticEngineState", "transcription:15"
        state = geneticEngine.state()
        state.name.should.eql "transcription"
        state.step.should.eql 15

      it "should provide stateBefore() and stateAfter() helper methods", ->
        model.set "geneticEngineState", "intro-cells"
        geneticEngine.stateBefore("dna").should.be.true
        geneticEngine.stateAfter("dna").should.be.false

        model.set "geneticEngineState", "transcription"
        geneticEngine.stateBefore("dna").should.be.false
        geneticEngine.stateAfter("dna").should.be.true
        geneticEngine.stateBefore("translation").should.be.true
        geneticEngine.stateAfter("translation").should.be.false
        geneticEngine.stateBefore("translation:15").should.be.true
        geneticEngine.stateAfter("translation:15").should.be.false

        model.set "geneticEngineState", "transcription:15"
        geneticEngine.stateBefore("transcription:14").should.be.false
        geneticEngine.stateAfter("transcription:14").should.be.true
        geneticEngine.stateBefore("transcription:15").should.be.false
        geneticEngine.stateAfter("transcription:15").should.be.false
        geneticEngine.stateBefore("transcription:16").should.be.true
        geneticEngine.stateAfter("transcription:16").should.be.false
