import pathlib,shlex,subprocess,sys
source=pathlib.Path(__file__).resolve().parents[2]
build=pathlib.Path(sys.argv[1]).resolve()
commands=subprocess.check_output(['ninja','-C',str(build),'-t','commands','AppKit'],text=True).splitlines()
lines=[c for c in commands if ' -c ' in c and '/NSView.m' in c]
if len(lines)!=1:raise RuntimeError('ambiguous AppKit SDK command')
args=shlex.split(lines[0]);flags=[];i=1
while i<len(args):
 a=args[i]
 if a in ('-o','-c','-MT','-MF'):i+=2;continue
 if a in ('-MD','-MMD'):i+=1;continue
 flags.append(a);i+=1
if '--candidate' in sys.argv:flags.insert(0,'-I'+str(source/'QuartzCore/include'))
subprocess.run([args[0],*flags,'-fsyntax-only',str(pathlib.Path(__file__).with_name('protocol.m'))],cwd=build,check=True)
