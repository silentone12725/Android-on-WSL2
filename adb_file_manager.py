#!/usr/bin/env python3
"""
ADB File Manager — v4.0 (Windows + Linux/macOS Compatible)
LineageOS Teal Theme + Full Windows Drive Support
"""

import os
import subprocess
import json
import time
import tempfile
import shutil
import traceback
import platform
import string
import ctypes
from http.server import HTTPServer, SimpleHTTPRequestHandler
from urllib.parse import parse_qs, urlparse
import cgi

PORT = 8765
IS_WINDOWS = platform.system() == 'Windows'

# -----------------------
# EMBEDDED HTML & CSS
# -----------------------
HTML = """
<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="utf-8" />
<meta name="viewport" content="width=device-width,initial-scale=1" />
<title>ADB File Manager</title>
<style>
/* =========================================================
   LINEAGE OS "TEAL IMMERSION" THEME
   Primary: #167C80
========================================================= */

:root {
  --bg: #050808;           
  --panel: #0F1616;        
  --input-bg: #090C0C;     
  --border: rgba(22, 124, 128, 0.25); 
  --text-main: #E0ECEC;    
  --text-muted: #849999;   
  --teal: #167C80;
  --teal-bright: #1EA6AB;
  --teal-surface: rgba(22, 124, 128, 0.18); 
  --teal-glow: rgba(22, 124, 128, 0.45);     
  --folder-color: #FFCA28; 
  --radius-lg: 14px;
  --radius-sm: 8px;
  --item-height: 60px;
}

* { box-sizing: border-box; margin: 0; padding: 0; user-select: none; }
body {
  background-color: var(--bg);
  background-image: radial-gradient(circle at 50% 0%, #101F1F 0%, #050808 60%);
  color: var(--text-main);
  font-family: 'Roboto', 'Inter', system-ui, sans-serif;
  height: 100vh;
  display: flex;
  flex-direction: column;
  overflow: hidden;
}

.app-container {
  max-width: 1600px;
  margin: 0 auto;
  width: 100%;
  height: 100%;
  padding: 20px;
  display: flex;
  flex-direction: column;
  gap: 15px;
}

header {
  display: flex;
  justify-content: space-between;
  align-items: center;
  padding: 5px 10px;
}

h1 {
  font-size: 22px;
  font-weight: 600;
  letter-spacing: 0.5px;
  color: var(--teal-bright);
  text-shadow: 0 0 20px rgba(22, 124, 128, 0.3);
}

.status-badge {
  background-color: rgba(255,255,255,0.03);
  border: 1px solid var(--border);
  color: var(--text-muted);
  padding: 6px 16px;
  border-radius: 20px;
  font-size: 13px;
  font-weight: 600;
  display: flex;
  align-items: center;
  gap: 8px;
  transition: all 0.3s ease;
}

.status-badge.connected {
  background-color: var(--teal);
  border-color: var(--teal-bright);
  color: #fff;
  box-shadow: 0 0 15px var(--teal-glow);
}

.status-dot { width: 8px; height: 8px; background-color: #555; border-radius: 50%; }
.status-badge.connected .status-dot { background-color: #fff; }

.split-view {
  display: flex;
  flex: 1;
  gap: 15px;
  min-height: 0; 
}

.panel {
  flex: 1;
  background-color: var(--panel);
  border-radius: var(--radius-lg);
  border: 1px solid var(--border);
  display: flex;
  flex-direction: column;
  overflow: hidden;
  position: relative;
  box-shadow: 0 10px 40px rgba(0,0,0,0.4); 
}

#leftPane { border-top: 3px solid var(--teal); } 
#rightPane { border-top: 3px solid var(--text-muted); }

.panel-header {
  padding: 15px;
  display: flex;
  flex-direction: column;
  gap: 10px;
  background: rgba(22, 124, 128, 0.03);
  border-bottom: 1px solid var(--border);
}

.panel-title {
  display: flex;
  align-items: center;
  gap: 8px;
  font-size: 14px;
  font-weight: 700;
  color: var(--teal);
  text-transform: uppercase;
  letter-spacing: 0.5px;
}

.path-bar { display: flex; gap: 8px; }
.path-input {
  flex: 1;
  background: var(--input-bg);
  border: 1px solid var(--border);
  color: var(--teal-bright);
  padding: 8px 12px;
  border-radius: var(--radius-sm);
  font-family: 'Consolas', monospace;
  font-size: 13px;
  outline: none;
  transition: border 0.2s;
}
.path-input:focus { border-color: var(--teal-bright); box-shadow: 0 0 10px rgba(22, 124, 128, 0.1); }

.nav-btn {
  background: var(--input-bg);
  border: 1px solid var(--border);
  color: var(--text-main);
  border-radius: var(--radius-sm);
  width: 36px;
  cursor: pointer;
  display: flex; align-items: center; justify-content: center;
  transition: all 0.2s;
}
.nav-btn:hover { background: var(--teal); border-color: var(--teal); color: #fff; }

.list-viewport { flex: 1; overflow-y: auto; position: relative; padding: 10px; }

.file-card {
  position: absolute;
  left: 10px; right: 10px;
  height: var(--item-height);
  display: flex;
  align-items: center;
  padding: 0 16px;
  border-radius: var(--radius-sm);
  cursor: pointer;
  transition: background 0.1s, transform 0.1s;
  border: 1px solid transparent;
}

.file-card:hover { background-color: rgba(22, 124, 128, 0.08); transform: translateX(2px); }

.file-card.selected {
  background-color: var(--teal-surface);
  border: 1px solid var(--teal);
  box-shadow: 0 0 15px rgba(22, 124, 128, 0.15);
}

.file-icon { font-size: 24px; margin-right: 16px; width: 30px; text-align: center; color: var(--teal); }
.is-folder .file-icon { filter: sepia(100%) saturate(500%) hue-rotate(0deg) brightness(1.1); color: transparent; text-shadow: 0 0 0 var(--folder-color); }
.is-drive .file-icon { filter: none; color: var(--text-main); text-shadow: 0 0 10px var(--teal); }

.file-info { display: flex; flex-direction: column; justify-content: center; overflow: hidden; }
.file-name { color: var(--text-main); font-size: 14px; font-weight: 500; white-space: nowrap; overflow: hidden; text-overflow: ellipsis; }
.file-meta { color: var(--text-muted); font-size: 12px; margin-top: 3px; }

.action-bar { display: flex; justify-content: center; gap: 20px; padding: 15px 0; }
.btn-action {
  height: 50px; padding: 0 28px; border-radius: 25px; border: none; font-size: 15px; font-weight: 700;
  cursor: pointer; display: flex; align-items: center; gap: 12px; transition: transform 0.1s, box-shadow 0.2s; letter-spacing: 0.5px;
}
.btn-action:disabled { opacity: 0.4; cursor: not-allowed; filter: grayscale(100%); transform: none !important; }
.btn-action:active:not(:disabled) { transform: scale(0.96); }

.btn-push {
  background: linear-gradient(135deg, var(--teal) 0%, var(--teal-bright) 100%);
  color: #fff; box-shadow: 0 6px 20px rgba(22, 124, 128, 0.4);
}
.btn-push:hover:not(:disabled) { box-shadow: 0 8px 25px rgba(22, 124, 128, 0.6); }

.btn-pull { background-color: transparent; color: var(--teal-bright); border: 2px solid var(--teal); }
.btn-pull:hover:not(:disabled) { background-color: var(--teal-surface); color: #fff; }

.terminal {
  height: 100px; background: rgba(0,0,0,0.5); border-radius: var(--radius-sm); border: 1px solid var(--border);
  padding: 10px; font-family: 'Consolas', monospace; font-size: 11px; color: var(--text-muted); overflow-y: auto;
}
::-webkit-scrollbar { width: 8px; }
::-webkit-scrollbar-track { background: transparent; }
::-webkit-scrollbar-thumb { background: #253333; border-radius: 4px; border: 1px solid transparent; background-clip: content-box; }
::-webkit-scrollbar-thumb:hover { background: var(--teal); }
</style>
</head>
<body>

<div class="app-container">
  <header>
    <h1>ADB File Manager</h1>
    <div id="statusBadge" class="status-badge">
      <div class="status-dot"></div>
      <span id="statusText">Connecting...</span>
    </div>
  </header>

  <div class="split-view">
    <div class="panel" id="leftPane">
      <div class="panel-header">
        <div class="panel-title">💻 Local Host</div>
        <div class="path-bar">
          <input id="linuxPath" class="path-input" value="__HOME__" aria-label="Local Path">
          <button class="nav-btn" id="linuxGo">Go</button>
          <button class="nav-btn" id="linuxUp">⬆</button>
        </div>
      </div>
      <div class="list-viewport" id="linuxViewport" data-type="linux">
        <div id="linuxPhantom"></div>
      </div>
    </div>
    
    <div class="panel" id="rightPane">
      <div class="panel-header">
        <div class="panel-title">📱 Android Device</div>
        <div class="path-bar">
          <input id="androidPath" class="path-input" value="/sdcard/" aria-label="Android Path">
          <button class="nav-btn" id="androidGo">Go</button>
          <button class="nav-btn" id="androidUp">⬆</button>
        </div>
      </div>
      <div class="list-viewport" id="androidViewport" data-type="android">
        <div id="androidPhantom"></div>
      </div>
    </div>
  </div>

  <div class="action-bar">
    <button id="pushBtn" class="btn-action btn-push" onclick="pushToAndroid()" disabled><span>➡</span> PUSH TO DEVICE</button>
    <button id="pullBtn" class="btn-action btn-pull" onclick="pullFromAndroid()" disabled><span>⬅</span> PULL TO HOST</button>
    <button id="installBtn" class="btn-action btn-pull" onclick="installApk()" style="display:none"><span>📦</span> INSTALL</button>
  </div>

  <div class="terminal" id="log">
    <div>[System] UI Initialized. Platform: __PLATFORM__</div>
  </div>
</div>

<script>
const ITEM_HEIGHT = 60;
const BUFFER_ITEMS = 10;
const DEBOUNCE_MS = 150;
const IS_WINDOWS = "__PLATFORM__" === "Windows";

let selectedLinux = new Map(); 
let selectedAndroid = new Map();

function log(msg){
  const el = document.getElementById('log');
  const time = new Date().toLocaleTimeString();
  el.innerHTML += `<div><span style="color:#167C80">[${time}]</span> ${msg}</div>`;
  el.scrollTop = el.scrollHeight;
}

function debounce(fn, ms){
  let t;
  return (...args)=>{ clearTimeout(t); t = setTimeout(()=>fn(...args), ms); };
}

function humanSize(b){ 
  if(!b || b<=0) return '-'; 
  const u=['B','KB','MB','GB','TB']; 
  let i=Math.floor(Math.log(b)/Math.log(1024)); 
  if(i<0) i=0; 
  return (b/Math.pow(1024,i)).toFixed(1)+' '+u[i]; 
}

function iconFor(f){ 
  if(f.is_drive) return '💾';
  if(f.is_dir) return '📁'; 
  const ext=(f.name.split('.').pop()||'').toLowerCase(); 
  const m={apk:'🤖', jpg:'🖼️', png:'🖼️', mp4:'🎬', mp3:'🎵', pdf:'📄', zip:'📦', py:'🐍', exe:'⚙️'}; 
  return m[ext]||'📄'; 
}

function createFileNode(f, type){
  const node = document.createElement('div');
  let cls = 'file-card';
  if(f.is_dir) cls += ' is-folder';
  if(f.is_drive) cls += ' is-drive';
  node.className = cls;
  node.style.top = '0px'; 
  node.innerHTML = `
    <div class="file-icon">${iconFor(f)}</div>
    <div class="file-info">
      <div class="file-name">${f.name}</div>
      <div class="file-meta">${f.is_dir ? (f.is_drive ? 'Drive' : 'Folder') : humanSize(f.size)} ${f.modified !== '-' ? '• '+f.modified : ''}</div>
    </div>
  `;
  node._file = f;
  node.dataset.path = f.path;
  return node;
}

function setupVirtualList(viewport, phantom, items, type){
  viewport._items = items;
  viewport._pool = new Map();
  phantom.style.height = (items.length * ITEM_HEIGHT) + 'px';

  const render = () => {
    const scrollTop = viewport.scrollTop;
    const viewH = viewport.clientHeight;
    const start = Math.max(0, Math.floor(scrollTop / ITEM_HEIGHT) - BUFFER_ITEMS);
    const end = Math.min(items.length - 1, Math.ceil((scrollTop + viewH) / ITEM_HEIGHT) + BUFFER_ITEMS);
    
    const needed = new Set();
    for(let i=start; i<=end; i++) needed.add(i);

    for(const [idx, node] of viewport._pool){
      if(!needed.has(idx)){
        node.remove();
        viewport._pool.delete(idx);
      }
    }

    for(let i=start; i<=end; i++){
      if(!viewport._pool.has(i)){
        const f = items[i];
        const node = createFileNode(f, type);
        node.style.top = (i * ITEM_HEIGHT) + 'px';
        attachEvents(node, f, type);
        const map = type==='linux'?selectedLinux:selectedAndroid;
        if(map.has(f.path)) node.classList.add('selected');
        viewport.appendChild(node);
        viewport._pool.set(i, node);
      }
    }
  };
  
  viewport.onscroll = () => requestAnimationFrame(render);
  render(); 
}

function attachEvents(node, f, type){
  node.onclick = (e) => {
    if((f.is_dir || f.is_drive) && !e.ctrlKey && !e.shiftKey){
      if(f.name === '..'){ goUp(type); return; }
      if(type==='linux'){ 
         document.getElementById('linuxPath').value = f.path; 
         debouncedLoadLinux(); 
      } else { 
         document.getElementById('androidPath').value = f.path; 
         debouncedLoadAndroid(); 
      }
      return;
    }
    handleSelect(e, f, type, node);
  };
}

function handleSelect(e, f, type, node){
  const map = type==='linux' ? selectedLinux : selectedAndroid;
  const viewport = document.getElementById(type+'Viewport');
  
  if(!e.ctrlKey && !e.metaKey){
    map.clear();
    viewport.querySelectorAll('.selected').forEach(n => n.classList.remove('selected'));
  }
  
  if(map.has(f.path)){
    map.delete(f.path);
    node.classList.remove('selected');
  } else {
    map.set(f.path, f);
    node.classList.add('selected');
  }
  updateButtons();
}

function updateButtons(){
  document.getElementById('pushBtn').disabled = (selectedLinux.size === 0);
  document.getElementById('pullBtn').disabled = (selectedAndroid.size === 0);
  
  const installBtn = document.getElementById('installBtn');
  if(selectedLinux.size === 1){
    const f = selectedLinux.values().next().value;
    if(f.name.endsWith('.apk')){ installBtn.style.display = 'flex'; return; }
  }
  installBtn.style.display = 'none';
}

function goUp(type){
  const id = type==='linux' ? 'linuxPath' : 'androidPath';
  const el = document.getElementById(id);
  const parts = el.value.split('/').filter(Boolean);
  
  // Windows Logic
  if(type === 'linux' && IS_WINDOWS) {
      if(parts.length === 0) return; // Already at root
      if(parts.length === 1) {
          // At C:/ -> Go to Drives List
          el.value = '/'; 
          debouncedLoadLinux();
          return;
      }
  }

  parts.pop();
  let newPath = parts.join('/');
  
  if(type === 'linux' && IS_WINDOWS){
      // Fix C: to C:/
      if(newPath.length === 2 && newPath.endsWith(':')) newPath += '/';
  } else {
      if(!newPath.startsWith('/')) newPath = '/'+newPath;
  }
  
  if(!newPath) newPath = '/';
  el.value = newPath;
  if(type==='linux') debouncedLoadLinux(); else debouncedLoadAndroid();
}

async function fetchJson(url){
  const r = await fetch(url);
  if(!r.ok) throw new Error(await r.text());
  return await r.json();
}

async function loadLinux(){
  const path = document.getElementById('linuxPath').value;
  try {
    const data = await fetchJson('/api/linux/list?path='+encodeURIComponent(path));
    const vp = document.getElementById('linuxViewport');
    vp.innerHTML = '<div id="linuxPhantom"></div>';
    selectedLinux.clear(); updateButtons();
    setupVirtualList(vp, document.getElementById('linuxPhantom'), data.files, 'linux');
  } catch(e) { log('Error Local: '+e.message); }
}

async function loadAndroid(){
  const path = document.getElementById('androidPath').value;
  try {
    const data = await fetchJson('/api/android/list?path='+encodeURIComponent(path));
    const vp = document.getElementById('androidViewport');
    vp.innerHTML = '<div id="androidPhantom"></div>';
    selectedAndroid.clear(); updateButtons();
    setupVirtualList(vp, document.getElementById('androidPhantom'), data.files, 'android');
  } catch(e) { log('Error Android: '+e.message); }
}

const debouncedLoadLinux = debounce(loadLinux, DEBOUNCE_MS);
const debouncedLoadAndroid = debounce(loadAndroid, DEBOUNCE_MS);

async function pushToAndroid(){
  if(selectedLinux.size===0) return;
  const srcItems = Array.from(selectedLinux.values());
  const destPath = document.getElementById('androidPath').value;
  log(`Pushing ${srcItems.length} items to ${destPath}...`);
  
  const payload = {
    items: srcItems.map(f => ({
      source: f.path,
      dest: destPath + (destPath.endsWith('/')?'':'/') + f.name,
      is_dir: f.is_dir,
      name: f.name
    }))
  };
  
  try {
    const r = await fetch('/api/push', { method:'POST', body:JSON.stringify(payload) });
    const res = await r.json();
    if(res.success) log('Push Success.'); else log('Push Failed: '+JSON.stringify(res.errors));
    debouncedLoadAndroid();
  } catch(e){ log('Push Error: '+e); }
}

async function pullFromAndroid(){
  if(selectedAndroid.size===0) return;
  const srcItems = Array.from(selectedAndroid.values());
  const destPath = document.getElementById('linuxPath').value;
  log(`Pulling ${srcItems.length} items to ${destPath}...`);
  
  const payload = {
    items: srcItems.map(f => ({
      source: f.path, 
      dest: destPath + (destPath.endsWith('/')?'':'/') + f.name,
      is_dir: f.is_dir,
      name: f.name
    }))
  };

  try {
    const r = await fetch('/api/pull', { method:'POST', body:JSON.stringify(payload) });
    const res = await r.json();
    if(res.success) log('Pull Success.'); else log('Pull Failed: '+JSON.stringify(res.errors));
    debouncedLoadLinux();
  } catch(e){ log('Pull Error: '+e); }
}

async function installApk(){
  const f = selectedLinux.values().next().value;
  log('Installing '+f.name+'...');
  try {
    const r = await fetch('/api/install', {method:'POST', body:JSON.stringify({source: f.path})});
    const res = await r.json();
    if(res.success) log('Installed Successfully!'); else log('Install Failed: '+res.error);
  } catch(e){ log('Install Error: '+e); }
}

async function checkStatus(){
  try {
    const r = await fetchJson('/api/status');
    const badge = document.getElementById('statusBadge');
    const txt = document.getElementById('statusText');
    if(r.connected){
      badge.classList.add('connected');
      txt.innerText = "ADB Connected";
    } else {
      badge.classList.remove('connected');
      txt.innerText = "No Devices";
    }
  } catch(e){}
}

window.onload = function(){
  document.getElementById('linuxGo').onclick = debouncedLoadLinux;
  document.getElementById('linuxUp').onclick = () => goUp('linux');
  document.getElementById('androidGo').onclick = debouncedLoadAndroid;
  document.getElementById('androidUp').onclick = () => goUp('android');

  debouncedLoadLinux();
  debouncedLoadAndroid();
  setInterval(checkStatus, 3000);
  checkStatus();
};
</script>
</body>
</html>
"""

# -----------------------
# SERVER LOGIC
# -----------------------
class ADBFileServer(SimpleHTTPRequestHandler):
    def do_GET(self):
        parsed = urlparse(self.path)
        if parsed.path == '/':
            self.serve_html()
        elif parsed.path == '/api/linux/list':
            self.list_linux_files(parse_qs(parsed.query))
        elif parsed.path == '/api/android/list':
            self.list_android_files(parse_qs(parsed.query))
        elif parsed.path == '/api/status':
            self.check_adb_status()
        else:
            self.send_error(404)

    def do_POST(self):
        parsed = urlparse(self.path)
        length = int(self.headers.get('Content-Length', 0))
        body = self.rfile.read(length) if length else b'{}'
        try:
            data = json.loads(body.decode('utf-8'))
        except:
            data = {}

        if parsed.path == '/api/push':
            self.push_items(data)
        elif parsed.path == '/api/pull':
            self.pull_items(data)
        elif parsed.path == '/api/install':
            self.install_apk(data)
        else:
            self.send_error(404)

    def serve_html(self):
        try:
            # Replace placeholders for OS specific setup
            home = os.path.expanduser("~").replace("\\", "/")
            system_os = platform.system()
            html_out = HTML.replace("__HOME__", home).replace("__PLATFORM__", system_os)
            
            self.send_response(200)
            self.send_header('Content-Type', 'text/html; charset=utf-8')
            self.end_headers()
            self.wfile.write(html_out.encode('utf-8'))
        except Exception as e:
            self.send_error(500, str(e))

    def get_windows_drives(self):
        drives = []
        bitmask = ctypes.windll.kernel32.GetLogicalDrives()
        for letter in string.ascii_uppercase:
            if bitmask & 1:
                drives.append({
                    'name': f"{letter}:",
                    'is_dir': True,
                    'is_drive': True,
                    'size': 0,
                    'modified': '-',
                    'path': f"{letter}:/"
                })
            bitmask >>= 1
        return drives

    def list_linux_files(self, params):
        path = params.get('path', [os.path.expanduser('~')])[0]
        
        # Windows Root Logic
        if IS_WINDOWS:
            if path == '/' or path == '':
                self.send_json({'files': self.get_windows_drives()})
                return
            # Convert / to \ for os module, but keep drive letters clean
            local_path = path.replace('/', '\\')
            if len(local_path) == 2 and local_path[1] == ':': local_path += '\\'
        else:
            local_path = path

        try:
            items = []
            if IS_WINDOWS:
                if path != '/': items.append({'name':'..','is_dir':True,'size':0,'modified':'-','path':path})
            else:
                if path != '/': items.append({'name':'..','is_dir':True,'size':0,'modified':'-','path':path})
            
            for entry in os.scandir(local_path):
                try:
                    stats = entry.stat()
                    items.append({
                        'name': entry.name,
                        'is_dir': entry.is_dir(),
                        'is_drive': False,
                        'size': stats.st_size,
                        'modified': time.strftime('%Y-%m-%d %H:%M', time.localtime(stats.st_mtime)),
                        'path': entry.path.replace("\\", "/") # Normalize back to / for frontend
                    })
                except: continue
            
            items.sort(key=lambda x: (not x['is_dir'], x['name'].lower()))
            self.send_json({'files': items})
        except Exception as e:
            self.send_json({'files': [], 'error': str(e)}, 500)

    def list_android_files(self, params):
        path = params.get('path', ['/sdcard/'])[0]
        if not path.endswith('/'): path += '/'
        try:
            # ADB always uses Linux paths, so no conversion needed here
            cmd = ['adb', 'shell', 'ls', '-1p', path]
            r = subprocess.run(cmd, capture_output=True, text=True, timeout=5)
            if r.returncode != 0: raise Exception(r.stderr)
            
            items = []
            if path not in ['/', '/sdcard/']: items.append({'name':'..','is_dir':True,'size':0,'modified':'-','path':path})
            
            for line in r.stdout.splitlines():
                name = line.strip()
                if not name: continue
                is_dir = name.endswith('/')
                clean_name = name[:-1] if is_dir else name
                items.append({
                    'name': clean_name,
                    'is_dir': is_dir,
                    'size': 0, 
                    'modified': '-',
                    'path': path + clean_name
                })
            
            self.send_json({'files': items})
        except Exception as e:
            self.send_json({'files': [], 'error': str(e)}, 500)

    def check_adb_status(self):
        try:
            r = subprocess.run(['adb', 'devices'], capture_output=True, text=True, timeout=2)
            connected = any(line.endswith('\tdevice') or line.endswith(' device') for line in r.stdout.splitlines())
            self.send_json({'connected': connected})
        except:
            self.send_json({'connected': False})

    def push_items(self, data):
        items = data.get('items', [])
        success = True; errors = []
        for i in items:
            # Convert source (Local) to system path
            src = i['source'].replace('/', '\\') if IS_WINDOWS else i['source']
            cmd = ['adb', 'push', src, i['dest']]
            r = subprocess.run(cmd, capture_output=True, text=True)
            if r.returncode != 0:
                success = False
                errors.append(r.stderr)
        self.send_json({'success': success, 'errors': errors})

    def pull_items(self, data):
        items = data.get('items', [])
        success = True; errors = []
        for i in items:
            # Convert dest (Local) to system path
            dest = i['dest'].replace('/', '\\') if IS_WINDOWS else i['dest']
            cmd = ['adb', 'pull', i['source'], dest]
            r = subprocess.run(cmd, capture_output=True, text=True)
            if r.returncode != 0:
                success = False
                errors.append(r.stderr)
        self.send_json({'success': success, 'errors': errors})

    def install_apk(self, data):
        src = data.get('source')
        if IS_WINDOWS: src = src.replace('/', '\\')
        cmd = ['adb', 'install', '-r', src]
        r = subprocess.run(cmd, capture_output=True, text=True)
        if r.returncode == 0: self.send_json({'success': True})
        else: self.send_json({'success': False, 'error': r.stderr})

    def send_json(self, data, status=200):
        self.send_response(status)
        self.send_header('Content-Type', 'application/json')
        self.end_headers()
        self.wfile.write(json.dumps(data).encode('utf-8'))

def main():
    print(f"Starting ADB Manager on http://localhost:{PORT}")
    print(f"Platform: {platform.system()}")
    try:
        httpd = HTTPServer(('0.0.0.0', PORT), ADBFileServer)
        httpd.serve_forever()
    except KeyboardInterrupt:
        print("\nStopping...")

if __name__ == '__main__':
    main()