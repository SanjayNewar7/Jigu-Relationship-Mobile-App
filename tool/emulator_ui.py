import subprocess,sys,xml.etree.ElementTree as ET,re
adb=['adb','-s','emulator-5554']
subprocess.run(adb+['shell','uiautomator','dump','/sdcard/jigu-qa-ui.xml'],capture_output=True,check=True)
root=ET.fromstring(subprocess.check_output(adb+['shell','cat','/sdcard/jigu-qa-ui.xml']))
nodes=[n for n in root.iter('node') if n.attrib.get('package')=='com.sanjaya.jigulove']
if len(sys.argv)>1:
 target=sys.argv[1]
 matches=[n for n in nodes if target in (n.attrib.get('text'),n.attrib.get('content-desc'))]
 if not matches: raise SystemExit('Control not visible: '+target)
 points=list(map(int,re.findall(r'\d+',matches[0].attrib['bounds'])))
 subprocess.run(adb+['shell','input','tap',str((points[0]+points[2])//2),str((points[1]+points[3])//2)],check=True)
 print('Tapped:',target)
else:
 for n in nodes:
  label=n.attrib.get('text') or n.attrib.get('content-desc')
  if label: print(label[:110].replace('\n',' | '),n.attrib['bounds'])
