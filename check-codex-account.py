"""Check actual Codex account bootstrap without printing account data or tokens."""
import subprocess,json,selectors,time,sys
p=subprocess.Popen(['codex','app-server','--listen','stdio://'],stdin=subprocess.PIPE,stdout=subprocess.PIPE,stderr=subprocess.DEVNULL,text=True,bufsize=1)
s=selectors.DefaultSelector();s.register(p.stdout,selectors.EVENT_READ)
def send(d):p.stdin.write(json.dumps(d)+'\n');p.stdin.flush()
start=time.monotonic()
send({'id':1,'method':'initialize','params':{'clientInfo':{'name':'vpn_check','version':'1.0'}}})
try:
 while time.monotonic()-start<40:
  if not s.select(1):continue
  line=p.stdout.readline()
  if not line:break
  try:d=json.loads(line)
  except ValueError:continue
  if d.get('id')==1:
   if 'error' in d:print('initialize failed',d['error'].get('code'));sys.exit(1)
   send({'method':'initialized','params':{}});send({'id':2,'method':'account/read','params':{'refreshToken':False}})
  elif d.get('id')==2:
   if 'error' in d:print('account/read failed:',d['error'].get('message'),'seconds',round(time.monotonic()-start,2));sys.exit(1)
   r=d.get('result',{});print('account/read OK; account present:',r.get('account') is not None,'seconds',round(time.monotonic()-start,2));sys.exit(0 if r.get('account') is not None else 1)
 print('account/read no response within 40s');sys.exit(1)
finally:
 p.terminate()
 try:p.wait(timeout=4)
 except subprocess.TimeoutExpired:p.kill();p.wait()
