module main

import os
import strconv
import strings

const line_width = 60

const im = 139968

const ia = 3877

const ic = 29573

const alu = 'GGCCGGGCGCGGTGGCTCACGCCTGTAATCCCAGCACTTTGGGAGGCCGAGGCGGGCGGATCACCTGAGGTCAGGAGTTCGAGACCAGCCTGGCCAACATGGTGAAACCCCGTCTCTACTAAAAATACAAAAATTAGCCGGGCGTGGTGGCGCGCGCCTGTAATCCCAGCTACTCGGGAGGCTGAGGCAGGAGAATCGCTTGAACCCGGGAGGCGGAGGTTGCAGTGAGCCGAGATCGCGCCACTGCACTCCAGCCTGGGCGACAGAGCGAGACTCCGTCTCAAAAA'.bytes()

fn main() {
	mut n := 1
	if os.args.len == 2 {
		n = strconv.atoi(os.args[1]) or { 1 }
	}

	mut rand := RandGen{
		seed: 42
	}

	mut iub := {
		u8(`a`): 0.27
		u8(`c`): 0.12
		u8(`g`): 0.12
		u8(`t`): 0.27
		u8(`B`): 0.02
		u8(`D`): 0.02
		u8(`H`): 0.02
		u8(`K`): 0.02
		u8(`M`): 0.02
		u8(`N`): 0.02
		u8(`R`): 0.02
		u8(`S`): 0.02
		u8(`V`): 0.02
		u8(`W`): 0.02
		u8(`Y`): 0.02
	}

	mut homosapiens := {
		u8(`a`): 0.3029549426680
		u8(`c`): 0.1979883004921
		u8(`g`): 0.1975473066391
		u8(`t`): 0.3015094502008
	}

	make_repeat_fasta('ONE', 'Homo sapiens alu', alu, n * 2)
	make_random_fasta(mut rand, 'TWO', 'IUB ambiguity codes', mut iub, n * 3)
	make_random_fasta(mut rand, 'THREE', 'Homo sapiens frequency', mut homosapiens, n * 5)
}

fn make_repeat_fasta(id string, desc string, src []u8, n int) {
	println('>${id} ${desc}')
	mut char_print_idx := 0
	mut sb := strings.new_builder(line_width)
	defer {
		unsafe { sb.free() }
	}
	for _ in 0 .. (n / src.len + 1) {
		for c in src {
			sb.write_byte(c)
			char_print_idx += 1
			if char_print_idx >= n {
				if char_print_idx % line_width != 0 {
					println(sb.str())
				}
				break
			}

			if char_print_idx % line_width == 0 {
				println(sb.str())
				sb.go_back_to(0)
			}
		}
	}
}

fn make_random_fasta(mut rand_gen RandGen, id string, desc string, mut table map[u8]f64, n int) {
	println('>${id} ${desc}')
	mut prob := 0.0
	for k, p in table {
		prob += p
		table[k] = prob
	}

	mut n_char_printed := 0
	mut sb := strings.new_builder(line_width)
	defer {
		unsafe { sb.free() }
	}
	for _ in 0 .. n {
		rand := rand_gen.gen_random()
		for k, p in table {
			if p > rand {
				sb.write_byte(k)
				n_char_printed += 1
				if n_char_printed % line_width == 0 {
					println(sb.str())
					sb.go_back_to(0)
				}
				break
			}
		}
	}

	if n_char_printed % line_width != 0 {
		println(sb.str())
	}
}

struct RandGen {
mut:
	seed int
}

fn (mut r RandGen) gen_random() f64 {
	r.seed = (r.seed * ia + ic) % im
	return f64(r.seed) / f64(im)
}
