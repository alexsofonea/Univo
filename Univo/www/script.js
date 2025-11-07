(function () {
    // Vertex shader
    const vs = `
    attribute vec2 uv;

    uniform mat4 mvpMatrix;
    uniform vec2 resolution;
    uniform float time;

    varying vec2 vUv;
    varying float vPositionZ;

    //
    // Description : Array and textureless GLSL 2D/3D/4D simplex
    // noise functions.
    // Author : Ian McEwan, Ashima Arts.
    // Maintainer : ijm
    // Lastmod : 20110822 (ijm)
    // License : Copyright (C) 2011 Ashima Arts.
    //            Distributed under the MIT License.
    //            See LICENSE file.
    // https://github.com/ashima/webgl-noise

    vec3 mod289(vec3 x) {
      return x - floor(x * (1.0 / 289.0)) * 289.0;
    }
    vec4 mod289(vec4 x) {
      return x - floor(x * (1.0 / 289.0)) * 289.0;
    }
    vec4 permute(vec4 x) {
      return mod289(((x * 34.0) + 1.0) * x);
    }
    vec4 taylorInvSqrt(vec4 r)
    {
      return 1.79284291400159 - 0.85373472095314 * r;
    }
    float snoise(vec3 v)
    {
      const vec2  C = vec2(1.0/6.0, 1.0/3.0);
      const vec4  D = vec4(0.0, 0.5, 1.0, 2.0);
      // First corner
      vec3 i  = floor(v + dot(v, C.yyy) );
      vec3 x0 =   v - i + dot(i, C.xxx);

      // Other corners
      vec3 g = step(x0.yzx, x0.xyz);
      vec3 l = 1.0 - g;
      vec3 i1 = min( g.xyz, l.zxy );
      vec3 i2 = max( g.xyz, l.zxy );
      //   x0 = x0 - 0.0 + 0.0 * C.xxx;
      //   x1 = x0 - i1  + 1.0 * C.xxx;
      //   x2 = x0 - i2  + 2.0 * C.xxx;
      //   x3 = x0 - 1.0 + 3.0 * C.xxx;
      vec3 x1 = x0 - i1 + C.xxx;
      vec3 x2 = x0 - i2 + C.yyy; // 2.0*C.x = 1/3 = C.y
      vec3 x3 = x0 - D.yyy;      // -1.0+3.0*C.x = -0.5 = -D.y

      // Permutations
      i = mod289(i);
      vec4 p = permute( permute( permute(
                    i.z + vec4(0.0, i1.z, i2.z, 1.0 ))
                  + i.y + vec4(0.0, i1.y, i2.y, 1.0 ))
                  + i.x + vec4(0.0, i1.x, i2.x, 1.0 ));

      // Gradients: 7x7 points over a square, mapped onto an octahedron.
      // The ring size 17*17 = 289 is close to a multiple of 49 (49*6 = 294)
      float n_ = 0.142857142857; // 1.0/7.0
      vec3 ns = n_ * D.wyz - D.xzx;

      vec4 j = p - 49.0 * floor(p * ns.z * ns.z);  //  mod(p,7*7)

      vec4 x_ = floor(j * ns.z);
      vec4 y_ = floor(j - 7.0 * x_ );    //  mod(j,N)

      vec4 x = x_ * ns.x + ns.yyyy;
      vec4 y = y_ * ns.x + ns.yyyy;
      vec4 h = 1.0 - abs(x) - abs(y);

      vec4 b0 = vec4( x.xy, y.xy );
      vec4 b1 = vec4( x.zw, y.zw );

      vec4 s0 = floor(b0)*2.0 + 1.0;
      vec4 s1 = floor(b1)*2.0 + 1.0;
      vec4 sh = -step(h, vec4(0.0));

      vec4 a0 = b0.xzyw + s0.xzyw*sh.xxyy ;
      vec4 a1 = b1.xzyw + s1.xzyw*sh.zzww ;

      vec3 p0 = vec3(a0.xy,h.x);
      vec3 p1 = vec3(a0.zw,h.y);
      vec3 p2 = vec3(a1.xy,h.z);
      vec3 p3 = vec3(a1.zw,h.w);

      //Normalise gradients
      vec4 norm = taylorInvSqrt(vec4(dot(p0,p0), dot(p1,p1), dot(p2, p2), dot(p3,p3)));
      p0 *= norm.x;
      p1 *= norm.y;
      p2 *= norm.z;
      p3 *= norm.w;

      // Mix final noise value
      vec4 m = max(0.6 - vec4(dot(x0,x0), dot(x1,x1), dot(x2,x2), dot(x3,x3)), 0.0);
      m = m * m;
      return 42.0 * dot( m*m, vec4( dot(p0,x0), dot(p1,x1),
                                    dot(p2,x2), dot(p3,x3) ) );
    }

    vec3 snoiseVec3( vec3 x ){
      float s  = snoise(vec3( x ));
      float s1 = snoise(vec3( x.y - 19.1 , x.z + 33.4 , x.x + 47.2 ));
      float s2 = snoise(vec3( x.z + 74.2 , x.x - 124.5 , x.y + 99.4 ));
      vec3 c = vec3( s , s1 , s2 );
      return c;
    }

    vec3 curlNoise( vec3 p ){
      const float e = .1;
      vec3 dx = vec3( e   , 0.0 , 0.0 );
      vec3 dy = vec3( 0.0 , e   , 0.0 );
      vec3 dz = vec3( 0.0 , 0.0 , e   );

      vec3 p_x0 = snoiseVec3( p - dx );
      vec3 p_x1 = snoiseVec3( p + dx );
      vec3 p_y0 = snoiseVec3( p - dy );
      vec3 p_y1 = snoiseVec3( p + dy );
      vec3 p_z0 = snoiseVec3( p - dz );
      vec3 p_z1 = snoiseVec3( p + dz );

      float x = p_y1.z - p_y0.z - p_z1.y + p_z0.y;
      float y = p_z1.x - p_z0.x - p_x1.z + p_x0.z;
      float z = p_x1.y - p_x0.y - p_y1.x + p_y0.x;

      const float divisor = 1.0 / ( 2.0 * e );
      return normalize( vec3( x , y , z ) * divisor );
    }

    vec2 adjustRatio(vec2 coord, vec2 inputResolution, vec2 outputResolution) {
      vec2 ratio = vec2(
        min((outputResolution.x / outputResolution.y) / (inputResolution.x / inputResolution.y), 1.0),
        min((outputResolution.y / outputResolution.x) / (inputResolution.y / inputResolution.x), 1.0)
      );
      return coord * ratio + (1. - ratio) * 0.5;
    }

  uniform float uSpeed;
  uniform float uSize;
  uniform float uDensity;

    void main() {
      vUv = uv;

  vec2 cUv = adjustRatio(uv, vec2(1.), resolution);
  vec3 position = vec3(cUv * 2. - 1., 0.) + time * uSpeed;
  vec3 noise = curlNoise(position * uDensity);
  position = noise * min(resolution.x, resolution.y) * uSize;
      vPositionZ = noise.z;

      gl_Position = mvpMatrix * vec4(position, 1.);
    }
  `;

    // Fragment shader
    const fs = `
    precision highp float;

    uniform float time;
    uniform float uSpeed;

    varying vec2 vUv;
    varying float vPositionZ;

    const float PI = 3.1415926;
    const float PI2 = PI * 2.;

    const vec3 color = vec3(192., 235., 252.) / 255.;
    const float maxAlpha = 0.45;
    const float minAlpha = 0.01;

    void main() {
      float cAlpha = mix(minAlpha, maxAlpha, (sin(vUv.x * PI2 + time * uSpeed) + 1.) * 0.5);
      cAlpha *= mix(0.8, 1., vPositionZ);
      gl_FragColor = vec4(color, cAlpha);
    }
  `;

    // Texture shader
    const texture = `
    precision highp float;

    uniform vec2 resolution;
    uniform sampler2D texture;

    void main() {
      gl_FragColor = texture2D(texture, gl_FragCoord.st / resolution);
    }
  `;

    function addShaderScript(id, type, src) {
        var el = document.createElement('script');
        el.id = id;
        el.type = type;
        el.textContent = src;
        document.head.appendChild(el);
    }

    // create the shader script tags so Kgl can find them by id
    addShaderScript('vs', 'x-shader/x-vertex', vs);
    addShaderScript('fs', 'x-shader/x-fragment', fs);
    addShaderScript('texture', 'x-shader/x-fragment', texture);

    // ---------- Audio capture setup (microphone) ----------
    // We'll compute a smoothed RMS level and map it to shader uniforms.
    let audioCtx = null;
    let analyser = null;
    let audioStream = null;
    let dataArray = null;
    let audioSmoothed = 0;
    const audioSmoothing = 0.12; // EMA smoothing for RMS (bigger = smoother/slower)
    const noiseFloor = 0.01; // below this is treated as silence
    const audioUpper = 0.25; // RMS value mapped to max intensity

    // Smoothed uniform values for nicer transitions
    let uSpeedSmoothed = 0.1;
    let uSizeSmoothed = 0.24;
    let uDensitySmoothed = 0.7;
    // We'll smooth the time scale multiplier (not absolute time) so time never goes backwards
    let timeScaleSmoothed = 1.0;
    const uniformSmoothing = 0.12; // smoothing factor for uniforms (0..1)

    // Caps for how much voice can affect the animation
    const maxSpeedMultiplier = 2.0;   // uSpeed won't go above base * this
    const maxSizeMultiplier = 1.6;    // uSize won't go above base * this
    const maxDensityMultiplier = 1.4; // uDensity won't go above base * this
    const maxTimeScale = 1.4;         // time multiplier cap

    // Start audio capture and return a promise that resolves once the analyser is ready.
    // This allows us to attempt starting audio on load while keeping recording toggles separate.
    function startAudio() {
      return new Promise((resolve, reject) => {
        if (!navigator.mediaDevices || !navigator.mediaDevices.getUserMedia) return reject(new Error('getUserMedia not supported'));
        navigator.mediaDevices.getUserMedia({ audio: true }).then(stream => {
          try {
            audioCtx = new (window.AudioContext || window.webkitAudioContext)();
            audioStream = stream; // keep stream so we can reuse for recording
            const source = audioCtx.createMediaStreamSource(stream);
            analyser = audioCtx.createAnalyser();
            analyser.fftSize = 2048;
            // make the analyser itself smoother so the raw signal is less jumpy
            analyser.smoothingTimeConstant = 0.95;
            source.connect(analyser);
            dataArray = new Float32Array(analyser.fftSize);
            resolve(stream);
          } catch (err) {
            console.warn('startAudio failed', err);
            reject(err);
          }
        }).catch(err => {
          // user denied or not available — continue with default animation values
          console.warn('Microphone unavailable or permission denied', err);
          reject(err);
        });
      });
    }

    // Try to start audio capture right away so the animation responds continuously by default.
    // startAudio() returns a Promise; we don't await it here because permission prompts
    // may be shown and we don't want to block the rest of the script.
    startAudio().catch(() => {
      // We'll continue without audio; recording clicks can still request permission when needed.
    });

    // ---------- Recording toggle (click canvas to start/stop) ----------
    let mediaRecorder = null;
    let recordingChunks = [];
    let recording = false;
    // Fallback arrays for ScriptProcessor-based capture
    let pcmData = [];
    let pcmWorkerNode = null;

    // Helper: ensure we have a stream (start audio if needed)
    function ensureStream() {
      return new Promise((resolve, reject) => {
        if (audioStream) return resolve(audioStream);
        if (!navigator.mediaDevices || !navigator.mediaDevices.getUserMedia) return reject(new Error('getUserMedia not supported'));
        navigator.mediaDevices.getUserMedia({ audio: true }).then(stream => {
          audioStream = stream;
          // also create audioCtx/analyser if they don't exist
          if (!audioCtx) {
            audioCtx = new (window.AudioContext || window.webkitAudioContext)();
            const source = audioCtx.createMediaStreamSource(stream);
            analyser = audioCtx.createAnalyser();
            analyser.fftSize = 2048;
            analyser.smoothingTimeConstant = 0.95;
            source.connect(analyser);
            dataArray = new Float32Array(analyser.fftSize);
          }
          resolve(stream);
        }).catch(reject);
      });
    }

    // Encode PCM Float32Array buffers to WAV (16-bit) and return a Blob
    function encodeWAV(buffers, sampleRate) {
      // interleave and convert
      let totalLen = 0;
      for (let i = 0; i < buffers.length; i++) totalLen += buffers[i].length;
      const buffer = new ArrayBuffer(44 + totalLen * 2);
      const view = new DataView(buffer);

      function writeString(view, offset, string) {
        for (let i = 0; i < string.length; i++) {
          view.setUint8(offset + i, string.charCodeAt(i));
        }
      }

      /* RIFF identifier */ writeString(view, 0, 'RIFF');
      /* file length */ view.setUint32(4, 36 + totalLen * 2, true);
      /* RIFF type */ writeString(view, 8, 'WAVE');
      /* format chunk identifier */ writeString(view, 12, 'fmt ');
      /* format chunk length */ view.setUint32(16, 16, true);
      /* sample format (raw) */ view.setUint16(20, 1, true);
      /* channel count */ view.setUint16(22, 1, true);
      /* sample rate */ view.setUint32(24, sampleRate, true);
      /* byte rate (sampleRate * blockAlign) */ view.setUint32(28, sampleRate * 2, true);
      /* block align (channelCount * bytesPerSample) */ view.setUint16(32, 2, true);
      /* bits per sample */ view.setUint16(34, 16, true);
      /* data chunk identifier */ writeString(view, 36, 'data');
      /* data chunk length */ view.setUint32(40, totalLen * 2, true);

      // write the PCM samples
      let offset = 44;
      for (let i = 0; i < buffers.length; i++) {
        const input = buffers[i];
        for (let j = 0; j < input.length; j++, offset += 2) {
          let s = Math.max(-1, Math.min(1, input[j]));
          view.setInt16(offset, s < 0 ? s * 0x8000 : s * 0x7FFF, true);
        }
      }

      return new Blob([view], { type: 'audio/wav' });
    }

    // Convert Blob to base64 (dataURL) and extract base64 payload
    function blobToBase64(blob) {
      return new Promise((resolve, reject) => {
        const reader = new FileReader();
        reader.onloadend = () => {
          const dataUrl = reader.result;
          // data:[<mediatype>][;base64],<data>
          const comma = dataUrl.indexOf(',');
          const base64 = dataUrl.substring(comma + 1);
          resolve(base64);
        };
        reader.onerror = reject;
        reader.readAsDataURL(blob);
      });
    }

    async function startRecording() {
      try {
        // Prefer using the already-started audio stream so the animation runs continuously.
        if (!audioStream) {
          // If audio wasn't started yet, request it now (this may prompt the user).
          try {
            await startAudio();
          } catch (e) {
            console.warn('Could not start audio for recording', e);
            return;
          }
        }

        const stream = audioStream;

        recordingChunks = [];
        pcmData = [];

        if (window.MediaRecorder) {
          try {
            mediaRecorder = new MediaRecorder(stream);
          } catch (e) {
            mediaRecorder = null;
          }
        }

        if (mediaRecorder) {
          mediaRecorder.ondataavailable = e => {
            if (e.data && e.data.size) recordingChunks.push(e.data);
          };
          mediaRecorder.start();
          recording = true;
          return;
        }

        // Fallback: capture raw PCM via ScriptProcessorNode
        if (!audioCtx) audioCtx = new (window.AudioContext || window.webkitAudioContext)();
        const source = audioCtx.createMediaStreamSource(stream);
        const bufferSize = 2048;
        const recorderNode = (audioCtx.createScriptProcessor || audioCtx.createJavaScriptNode).call(audioCtx, bufferSize, 1, 1);
        recorderNode.onaudioprocess = function (e) {
          const input = e.inputBuffer.getChannelData(0);
          // clone the float32 data
          pcmData.push(new Float32Array(input));
        };
        source.connect(recorderNode);
        recorderNode.connect(audioCtx.destination); // some browsers require a destination connection
        pcmWorkerNode = recorderNode;
        recording = true;
      } catch (err) {
        console.warn('Recording start failed', err);
      }
    }

    async function stopRecordingAndSend() {
      try {
        recording = false;
        if (mediaRecorder && mediaRecorder.state !== 'inactive') {
          mediaRecorder.onstop = async () => {
            const blob = new Blob(recordingChunks, { type: 'audio/webm' });
            const base64 = await blobToBase64(blob);
            postToNative(base64);
          };
          mediaRecorder.stop();
          return;
        }

        // Fallback: stop script-processor and encode WAV
        if (pcmWorkerNode) {
          try {
            pcmWorkerNode.disconnect();
          } catch (e) {}
          pcmWorkerNode = null;
        }

        if (pcmData.length === 0) {
          // nothing recorded
          postToNative('');
          return;
        }

        // Flatten buffers
        const buffers = [];
        for (let i = 0; i < pcmData.length; i++) buffers.push(pcmData[i]);
        const sampleRate = (audioCtx && audioCtx.sampleRate) ? audioCtx.sampleRate : 44100;
        const wav = encodeWAV(buffers, sampleRate);
        const base64 = await blobToBase64(wav);
        postToNative(base64);
      } catch (err) {
        console.warn('Recording stop failed', err);
      }
    }

    function postToNative(base64Audio) {
      const payload = {
        action: 'taskInit',
        data: base64Audio
      };
      if (window.webkit && window.webkit.messageHandlers && window.webkit.messageHandlers.callbackHandler && window.webkit.messageHandlers.callbackHandler.postMessage) {
        window.webkit.messageHandlers.callbackHandler.postMessage(payload);
      } else {
        // fallback for desktop browsers while testing
        console.log('postMessage payload:', payload);
      }
    }

    // Toggle recording when clicking the canvas
    const canvasEl = document.getElementById('canvas');
    if (canvasEl) {
      canvasEl.addEventListener('click', async () => {
        if (!recording) {
          await startRecording();
          // optional visual feedback could be added here
        } else {
          await stopRecordingAndSend();
        }
      });
    }

    // Adapted from original pen:
    const particleOneSideNum = window.innerWidth < 768 ? 400 : 800;
    const bloomRadius = 8;

    const uv = [];
    const maxI = particleOneSideNum - 1;
    for (let j = 0; j < particleOneSideNum; j++) {
        for (let i = 0; i < particleOneSideNum; i++) {
            uv.push(i / maxI, 1 - j / maxI);
        }
    }

    // Create Kgl. We keep the contextAttributes here to allow alpha.
    const webgl = new Kgl({
        canvas: document.getElementById('canvas'),
        contextAttributes: {
            alpha: true,
            premultipliedAlpha: false
        },
        cameraPosition: [0, 0, Math.min(window.innerWidth, window.innerHeight) / 2],
        programs: {
            main: {
                vertexShaderId: 'vs',
                fragmentShaderId: 'fs',
                attributes: {
                    uv: {
                        value: uv,
                        size: 2
                    }
                },
                // expose audio-driven uniforms with sensible defaults
                uniforms: {
                    time: 0,
                    uSpeed: 0.1,
                    uSize: 0.24,
                    uDensity: 0.7,
                    resolution: [window.innerWidth * 2, window.innerHeight * 2]
                },
                mode: 'LINE_STRIP',
                isTransparent: true
            },
            output: {
                fragmentShaderId: 'texture',
                uniforms: {
                    texture: 'framebuffer'
                },
                clearedColor: [0, 0, 0, 0],
                isTransparent: true
            }
        },
        effects: [
            'bloom'
        ],
        framebuffers: [
            'main',
            'cache',
            'output'
        ],
        onBefore: () => {

        },
        tick: time => {
            // sample audio (if available) and compute smoothed RMS intensity
            let intensity = 0;
            if (analyser && dataArray) {
                analyser.getFloatTimeDomainData(dataArray);
                let sum = 0;
                for (let i = 0; i < dataArray.length; i++) {
                    const v = dataArray[i];
                    sum += v * v;
                }
                const rms = Math.sqrt(sum / dataArray.length);
                audioSmoothed = audioSmoothed * (1 - audioSmoothing) + rms * audioSmoothing;
                // map from noiseFloor..audioUpper -> 0..1
                intensity = Math.max(0, (audioSmoothed - noiseFloor) / (audioUpper - noiseFloor));
                intensity = Math.min(1, intensity);
            }

            // Map intensity to uniforms
            const baseSpeed = 0.1;
            const baseSize = 0.24;
            const baseDensity = 0.7;
            // Compute desired (target) uniform values but clamp them to safe maxima
            const targetSpeed = baseSpeed * Math.min(maxSpeedMultiplier, 1 + intensity * (maxSpeedMultiplier - 1));
            const targetSize = baseSize * Math.min(maxSizeMultiplier, 1 + intensity * (maxSizeMultiplier - 1));
            const targetDensity = baseDensity * Math.min(maxDensityMultiplier, 1 + intensity * (maxDensityMultiplier - 1));

            // scale time so the animation feels faster when speaking (clamped)
            const targetTimeScale = Math.min(maxTimeScale, 1 + intensity * (maxTimeScale - 1));

            // Smoothly interpolate uniforms to their targets for a softer transition
            uSpeedSmoothed = uSpeedSmoothed + (targetSpeed - uSpeedSmoothed) * uniformSmoothing;
            uSizeSmoothed = uSizeSmoothed + (targetSize - uSizeSmoothed) * uniformSmoothing;
            uDensitySmoothed = uDensitySmoothed + (targetDensity - uDensitySmoothed) * uniformSmoothing;

            // Smooth the time scale multiplier only — since 'time' is monotonically increasing,
            // multiplying it by a smoothed scale guarantees the draw-time never goes backward.
            timeScaleSmoothed = timeScaleSmoothed + (targetTimeScale - timeScaleSmoothed) * (uniformSmoothing * 0.9);
            const drawTime = time * timeScaleSmoothed;

            webgl.bindFramebuffer('main');
            webgl.programs.main.draw({ time: drawTime, uSpeed: uSpeedSmoothed, uSize: uSizeSmoothed, uDensity: uDensitySmoothed, resolution: [webgl.canvas.width, webgl.canvas.height] });
            webgl.effects.bloom.draw('main', 'cache', 'output', bloomRadius);

            webgl.unbindFramebuffer();
            webgl.programs.output.draw({ texture: 'output' });
        }
    });

})();
