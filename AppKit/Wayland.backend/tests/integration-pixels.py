from pathlib import Path
import json,subprocess,sys
p=Path(sys.argv[1]);results=[]
for case,name,scale in [('normal-reviewed','drag',1),('modifier-reviewed','drag',1),('scale-reviewed','drag',1),('scale-reviewed','scale2',2)]:
 image=p/('run-'+case)/(name+'.png');data=subprocess.check_output(['magick',str(image),'-depth','8','RGB:-'])
 r={'case':case,'image':str(image),'scale':scale}
 for label,color,area in [('EGL',b'\xff\x00\xff',300*220+40*40),('icon',b'\xff\xff\x00',32*24)]:
  got=sum(data[i:i+3]==color for i in range(0,len(data),3));expected=area*scale*scale;r[label]={'pixels':got,'expected':expected,'pass':got==expected}
 results.append(r)
(p/'pixels.json').write_text(json.dumps(results,indent=2));print(json.dumps(results));raise SystemExit(any(not r[k]['pass'] for r in results for k in ['EGL','icon']))
