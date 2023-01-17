import 'package:rohd/rohd.dart';

import 'counter.dart';

enum OvenStates { standby, cooking, paused, completed }

class Button extends Const {
  Button._(int super.value) : super(width: 2);
  Button.start() : this._(bin('00'));
  Button.pause() : this._(bin('01'));
  Button.resume() : this._(bin('10'));
}

class LEDLight extends Const {
  LEDLight._(int super.value) : super(width: 2);
  LEDLight.yellow() : this._(bin('00'));
  LEDLight.blue() : this._(bin('01'));
  LEDLight.red() : this._(bin('10'));
  LEDLight.green() : this._(bin('11'));
}

class OvenModule extends Module {
  OvenModule(Logic button, Logic reset) : super(name: 'OvenModule') {
    // input to FSM
    button = addInput('button', button, width: button.width);

    // output to FSM
    final led = addOutput('led', width: button.width);

    // add clock & reset
    final clk = SimpleClockGenerator(10).clk;
    reset = addInput('reset', reset);

    // add time elapsed Counter
    var counterReset = Logic(name: 'counter_reset');
    var en = Logic(name: 'counter_en');
    final counter = Counter(en, counterReset, clk, name: 'counter_module');

    final states = [
      State<OvenStates>(OvenStates.standby, events: {
        button.eq(Button.start()): OvenStates.cooking,
      }, actions: [
        led < LEDLight.blue().value,
        counterReset < 1,
        en < 0,
      ]),
      // Cooking State (Need to count here)
      State<OvenStates>(OvenStates.cooking, events: {
        button.eq(Button.pause()): OvenStates.paused,
        counter.val.eq(2): OvenStates.completed
      }, actions: [
        led < LEDLight.yellow().value,
        en < 1,
        counterReset < 0,
      ]),
      State<OvenStates>(OvenStates.paused, events: {
        button.eq(Button.resume()): OvenStates.cooking
      }, actions: [
        led < LEDLight.red().value,
      ]),
      State<OvenStates>(OvenStates.completed, events: {
        button.eq(Button.start()): OvenStates.cooking
      }, actions: [
        led < LEDLight.green().value,
        counterReset < 1,
        en < 0,
      ])
    ];

    StateMachine<OvenStates>(clk, reset, OvenStates.standby, states);
  }
}

void main() async {
  final button = Logic(name: 'button', width: 2);
  final reset = Logic(name: 'reset');

  // Create a counter Module
  final oven = OvenModule(button, reset);

  // build
  await oven.build();

  print(oven.generateSynth());

  reset.inject(1);

  Simulator.registerAction(25, () => reset.put(0));
  Simulator.registerAction(25, () {
    button.put(bin('00'));
  });

  WaveDumper(oven, outputPath: 'tutorials/08_fsm/oven.vcd');

  Simulator.registerAction(100, () {
    print('Simulation End');
  });

  Simulator.setMaxSimTime(100);

  await Simulator.run();
}
