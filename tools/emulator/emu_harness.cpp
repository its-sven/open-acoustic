// Analysis-only harness: boot the TC-Helicon Play Acoustic DSP image in the dsp56300 emulator
// and dump its RAM once start-up has built the tables (parameter descriptors, menus, value lists). It also prints the
// stock MIDI CC map (QSCCMapList; see legacy/cc-approach). Never talks to hardware.
#include <cstdio>
#include <cstdlib>
#include <string>
#include <vector>
#include <map>
#include <unordered_map>
#include <algorithm>
#include <fstream>
#include <dirent.h>

#include "dsp56kEmu/dsp.h"
#include "dsp56kEmu/memory.h"
#include "dsp56kEmu/peripherals.h"

using namespace dsp56k;
static DSP* g_dsp = nullptr; static TWord g_d0 = 0;

static std::vector<uint8_t> readFile(const std::string& p) {
	std::ifstream f(p, std::ios::binary); return std::vector<uint8_t>((std::istreambuf_iterator<char>(f)), {});
}

int main(int argc, char** argv) {
	if (argc < 3) { fprintf(stderr, "usage: harness <recdir> <maxMInstr> [watch_hex...]\n"); return 1; }
	setvbuf(stdout,nullptr,_IONBF,0);
	const std::string dir = argv[1];
	const uint64_t maxInstr = (uint64_t)atof(argv[2]) * 1000000ull;

	static DefaultMemoryValidator validator;
	// P: 16M words (covers X:$FFFExx device regs once bridged), X/Y bridged to P from $400000 (unified external RAM)
	Memory mem(validator, 0x1000000, 0x1000000, 0x400000);
	printf("mem ok\n");
	Peripherals56367 p67;
	Peripherals56362 p62(&p67);
	// Start-up waits for bit 23 of Y:$FFFFE5 (external status). Report it as set.
	p67.setIoExtension(
		[](TWord a, TWord& v) {
			if (a == 0xffffe5) { v = 0x800000; return true; }
			if (a == 0xffffd1) {	// second-core block-transfer handshake (no second core is emulated)
				const TWord pc = g_dsp ? g_dsp->getPC().toWord() : 0;
				if (g_d0 & 0x800000) v = 0x5a0; else if (pc >= 0x40caf5 && pc <= 0x40caf9) v = 0xa5a5a; else v = 0;
				return true; }
			return false; },
		[](TWord a, TWord v) { if (a == 0xffffd0) g_d0 = v; return false; });
	printf("periph ok\n");
	DSP dsp(mem, &p62, &p67);
	g_dsp = &dsp;
	if (!getenv("ESAI")) p62.getEsaiClock().setEnabled(false);
	if (getenv("NOTIMERS")) p62.disableTimers(true);
	printf("dsp ok\n");

	// load records rNN_<P|X>_<addr>.bin
	DIR* d = opendir(dir.c_str()); dirent* e; int n = 0;
	std::vector<std::string> files;
	while ((e = readdir(d))) { std::string s = e->d_name; if (s.size() > 4 && s.substr(s.size() - 4) == ".bin" && s[0] == 'r') files.push_back(s); }
	closedir(d); std::sort(files.begin(), files.end());
	for (auto& s : files) {
		const char area = s[4]; const TWord base = (TWord)strtoul(s.substr(6, 6).c_str(), nullptr, 16);
		auto b = readFile(dir + "/" + s);
		for (size_t i = 0; i + 2 < b.size(); i += 3) {
			TWord w = (b[i] << 16) | (b[i + 1] << 8) | b[i + 2];
			mem.set(area == 'P' ? MemArea_P : MemArea_X, base + (TWord)(i / 3), w);
		}
		printf("loaded %s -> %c:%06x (%zu words)\n", s.c_str(), area, base, b.size() / 3); ++n;
	}

	// emulate the flashed image: the flash writer patches P:$1AE (jmp target) to $1AF = normal application start
	if (!getenv("NOPATCH")) mem.set(MemArea_P, 0x1ae, 0x1af);
	printf("starting\n");
	dsp.setPC(0xcb);
	if (getenv("TRACE")) { int t=atoi(getenv("TRACE")); for (int q=0;q<t;++q){ fprintf(stderr,"%06x\n",dsp.getPC().toWord()); if (getenv("BRK") && dsp.getPC().toWord()==(TWord)strtoul(getenv("BRK"),nullptr,16)) { auto& R=dsp.regs(); fprintf(stderr,"BRK x=%012llx a=%014llx b=%014llx r2=%06x r5=%06x r6=%06x n2=%06x\n",(unsigned long long)R.x.var,(unsigned long long)R.a.var,(unsigned long long)R.b.var,R.r[2].toWord(),R.r[5].toWord(),R.r[6].toWord(),R.n[2].toWord()); } (getenv("INTERP") ? dsp.execInterpreter() : dsp.exec()); } }
	std::unordered_map<TWord, uint64_t> hist;
	uint64_t i = 0; TWord lastMap = 0, lastSize = 0;
	const uint64_t chunk = getenv("CHUNK") ? atoll(getenv("CHUNK")) : 2000000;
	while (i < maxInstr) {
		for (uint64_t k = 0; k < chunk; ++k) { (getenv("INTERP") ? dsp.execInterpreter() : dsp.exec()); if ((k & 63) == 0) ++hist[dsp.getPC().toWord()]; }
		i += chunk;
		TWord mp = mem.get(MemArea_X, 0x7e89ad), ms = mem.get(MemArea_X, 0x7e89ae);
		if (true)
			printf("[%6.0fM] pc=%06x  QSCCMapList map=%06x size=%06x\n", i / 1e6, dsp.getPC().toWord(), mp, ms);
		lastMap = mp; lastSize = ms;
	}
	// hottest PCs = where it loops / waits
	std::vector<std::pair<TWord, uint64_t>> hv(hist.begin(), hist.end());
	std::sort(hv.begin(), hv.end(), [](auto& a, auto& b) { return a.second > b.second; });
	printf("hot PCs:"); for (size_t k = 0; k < std::min<size_t>(12, hv.size()); ++k) printf(" %06x(%llu)", hv[k].first, (unsigned long long)hv[k].second); printf("\n");

	// dump regions for offline inspection
	auto dump = [&](const char* fn, EMemArea a, TWord from, TWord to) {
		FILE* f = fopen(fn, "wb");
		for (TWord x = from; x < to; ++x) { TWord w = mem.get(a, x); uint8_t bb[3] = { (uint8_t)(w >> 16), (uint8_t)(w >> 8), (uint8_t)w }; fwrite(bb, 1, 3, f); }
		fclose(f);
	};
	dump("ram_X_7E0000-7EFFFF.bin", MemArea_X, 0x7e0000, 0x7f0000);
	dump("ram_X_440000-47FFFF.bin", MemArea_X, 0x440000, 0x480000);
	dump("ram_X_030000-039FFF.bin", MemArea_X, 0x030000, 0x03a000);

	TWord mp = mem.get(MemArea_X, 0x7e89ad), ms = mem.get(MemArea_X, 0x7e89ae);
	printf("FINAL QSCCMapList: map=%06x size=%u\n", mp, ms);
	if (mp && ms && ms < 4096) {
		for (TWord c = 0; c < ms; ++c) {
			TWord p0 = mem.get(MemArea_X, mp + 2 * c), p1 = mem.get(MemArea_X, mp + 2 * c + 1);
			if (p0 != 0xffffff) printf("  CC %3u -> param 0x%06x  aux 0x%06x\n", c, p0, p1);
		}
	}
	return 0;
}
