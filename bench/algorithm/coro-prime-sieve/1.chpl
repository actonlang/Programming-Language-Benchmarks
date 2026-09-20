use List;

config const n = 10;

record Channel {
    var ch: sync int;

    proc init() {}

    proc ref send(i: int) {
        ch.writeEF(i);
    }

    proc ref receive(): int {
        return ch.readFE();
    }
}

proc main() {
  var channels = new list(Channel);
  for i in 1..n {
      channels.pushBack(new Channel());
  }
  begin with (ref channels) generate(channels[0]);
  for i in 1..n {
    ref ch = channels[i-1];
    const prime = ch.receive();
    writeln(prime);
    if i < n {
        begin with (ref ch, ref channels) filter(ch, channels[i], prime);
    }
  }
  exit(0);
}

proc generate(ref ch: Channel) {
    var i = 2;
    do {
        ch.send(i);
        i += 1;
    } while(true);
}

proc filter(ref chIn: Channel, ref chOut: Channel, prime: int) {
    do {
        const i = chIn.receive();
        if i % prime != 0 {
            chOut.send(i);
        }
    } while(true);
}
