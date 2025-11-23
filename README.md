React + TS Game Project File:

```
import React, { useEffect, useRef, useState } from 'react';
import { GameEngine } from './GameEngine';
import { GameState, AIState } from './types';

export default function App() {
    const containerRef = useRef<HTMLDivElement>(null);
    const gameRef = useRef<GameEngine | null>(null);
    
    const [gameState, setGameState] = useState<GameState>(GameState.MENU);
    const [score, setScore] = useState(0);
    const [finalScore, setFinalScore] = useState(0);
    const [autoPilot, setAutoPilot] = useState(false);
    
    // AI Debug State
    const [aiState, setAiState] = useState<AIState>({
        enabled: false,
        currentLane: 0,
        targetLane: 0,
        action: 'SCANNING',
        confidence: 0,
        nearestThreatDist: 0,
        laneScores: [0,0,0]
    });

    useEffect(() => {
        if (!containerRef.current) return;

        const game = new GameEngine(
            containerRef.current,
            (s) => setScore(s),
            (s) => {
                setFinalScore(s);
                setGameState(GameState.GAME_OVER);
            },
            (state) => setAiState(state) // Update AI UI
        );
        gameRef.current = game;

        return () => game.cleanup();
    }, []);

    useEffect(() => {
        // Keyboard listeners
        const handleKey = (e: KeyboardEvent) => {
            if (!gameRef.current || gameState !== GameState.PLAYING) return;
            
            // Manual overrides work even in Auto Pilot (Hybrid/Smart control)
            switch(e.key) {
                case 'ArrowLeft': case 'a': gameRef.current.moveLeft(); break;
                case 'ArrowRight': case 'd': gameRef.current.moveRight(); break;
                case 'ArrowUp': case 'w': case ' ': gameRef.current.jump(); break;
                case 'ArrowDown': case 's': gameRef.current.roll(); break;
            }
        };

        window.addEventListener('keydown', handleKey);
        return () => window.removeEventListener('keydown', handleKey);
    }, [gameState]);

    // Touch controls
    const [touchStart, setTouchStart] = useState({ x: 0, y: 0 });

    const handleTouchStart = (e: React.TouchEvent) => {
        setTouchStart({ x: e.touches[0].clientX, y: e.touches[0].clientY });
    };

    const handleTouchEnd = (e: React.TouchEvent) => {
        if (!gameRef.current || gameState !== GameState.PLAYING) return;
        
        const endX = e.changedTouches[0].clientX;
        const endY = e.changedTouches[0].clientY;
        const diffX = endX - touchStart.x;
        const diffY = endY - touchStart.y;

        if (Math.abs(diffX) > Math.abs(diffY)) {
            if (Math.abs(diffX) > 30) {
                if (diffX > 0) gameRef.current.moveRight();
                else gameRef.current.moveLeft();
            }
        } else {
            if (Math.abs(diffY) > 30) {
                if (diffY < 0) gameRef.current.jump();
                else gameRef.current.roll();
            }
        }
    };

    const startGame = () => {
        if (gameRef.current) {
            gameRef.current.start();
            setGameState(GameState.PLAYING);
        }
    };

    const toggleAutoPilot = () => {
        const newVal = !autoPilot;
        setAutoPilot(newVal);
        if (gameRef.current) {
            gameRef.current.toggleAutoPilot(newVal);
        }
    };

    // Helper for AI Lane Visualizer
    const getLaneColor = (laneIdx: number) => {
        if (laneIdx === aiState.targetLane) return 'bg-cyan-400 shadow-[0_0_10px_#0ff]';
        if (laneIdx === aiState.currentLane) return 'bg-white/50';
        return 'bg-gray-800/50';
    };
    
    // AI Reasoning Text
    const getAIReason = () => {
        if (aiState.confidence === 0) return "PANIC: EVASIVE MANEUVERS";
        if (aiState.action === 'DODGE') return "AVOIDING SOLID OBSTACLE";
        if (aiState.targetLane !== aiState.currentLane) return "OPTIMIZING PATH (COINS)";
        if (aiState.action === 'JUMP') return "DETECTED BARRIER - JUMPING";
        if (aiState.action === 'DUCK') return "DETECTED OVERHEAD - ROLLING";
        return "CRUISING";
    };

    return (
        <div 
            className="relative w-full h-screen overflow-hidden bg-black select-none"
            onTouchStart={handleTouchStart}
            onTouchEnd={handleTouchEnd}
        >
            {/* 3D Canvas Container */}
            <div ref={containerRef} className="absolute inset-0 z-0" />

            {/* AI HUD / DEBUG OVERLAY */}
            {gameState === GameState.PLAYING && autoPilot && (
                <div className="absolute top-24 left-6 z-10 w-72 pointer-events-none font-mono text-xs">
                    <div className={`bg-black/80 border backdrop-blur-md p-4 rounded-lg relative overflow-hidden shadow-lg transition-colors duration-300 ${aiState.confidence < 50 ? 'border-red-500/50' : 'border-cyan-500/30 text-cyan-100'}`}>
                        <div className="absolute top-0 left-0 w-full h-1 bg-gradient-to-r from-transparent via-cyan-500 to-transparent animate-pulse opacity-50"></div>
                        
                        <div className="flex justify-between items-center mb-3">
                            <span className="font-bold tracking-widest text-cyan-400">AI NEURAL NET</span>
                            <span className={`px-2 py-0.5 rounded text-[10px] font-bold ${aiState.confidence > 80 ? 'bg-green-500/20 text-green-400' : (aiState.confidence > 40 ? 'bg-yellow-500/20 text-yellow-400' : 'bg-red-500/20 text-red-400')}`}>
                                {aiState.confidence}% CONFIDENCE
                            </span>
                        </div>

                        <div className="space-y-1 mb-4">
                            <div className="flex justify-between">
                                <span className="text-gray-400">STATUS</span>
                                <span className={`font-bold ${aiState.action === 'DODGE' ? 'text-orange-400' : 'text-white'}`}>
                                    {getAIReason()}
                                </span>
                            </div>
                            <div className="flex justify-between">
                                <span className="text-gray-400">NEXT ACTION</span>
                                <span className="font-bold text-white">{aiState.action}</span>
                            </div>
                            <div className="flex justify-between">
                                <span className="text-gray-400">THREAT DIST</span>
                                <span className="font-mono text-cyan-200">{aiState.nearestThreatDist < 9000 ? aiState.nearestThreatDist.toFixed(1) + 'm' : 'CLEAR'}</span>
                            </div>
                        </div>

                        {/* Lane Viz */}
                        <div className="flex gap-2 h-24 items-end justify-center pb-1 border-t border-white/10 pt-2">
                            {[-1, 0, 1].map((lane, idx) => {
                                const score = aiState.laneScores[idx] || 0;
                                // Normalize score for display (rough approximation since scores can be negative)
                                const heightPercent = Math.max(10, Math.min(100, (score + 100) / 2));
                                
                                return (
                                    <div key={lane} className="w-12 relative flex flex-col items-center group">
                                        <span className="text-[9px] text-gray-400 mb-1 z-20 font-bold">{score > -9000 ? score : 'DEAD'}</span>
                                        {/* Score bar height viz */}
                                        <div 
                                            className={`absolute bottom-6 w-full z-0 rounded-t-sm transition-all duration-300 ${score < -100 ? 'bg-red-900/40' : 'bg-cyan-900/40'}`}
                                            style={{ height: `${heightPercent}%` }}
                                        ></div>
                                        
                                        {/* Lane Indicator */}
                                        <div className={`w-3 h-full rounded-full transition-all duration-300 z-10 ${getLaneColor(lane)} ${lane === aiState.targetLane ? 'h-12 scale-110' : 'h-8'}`}></div>
                                        
                                        <span className="text-[9px] text-gray-500 mt-1 z-10">L{lane}</span>
                                    </div>
                                );
                            })}
                        </div>
                    </div>
                </div>
            )}

            {/* HUD */}
            <div className="absolute top-0 left-0 w-full p-6 flex justify-between items-start pointer-events-none z-10">
                <div className="flex flex-col gap-2">
                    <h1 className="text-2xl font-bold text-white neon-text opacity-80 tracking-widest">NEON RUNNER</h1>
                    {gameState === GameState.PLAYING && (
                         <div className={`pointer-events-auto flex items-center gap-2 border bg-black/40 backdrop-blur px-4 py-2 rounded-full transition-all duration-500 ${autoPilot ? 'shadow-[0_0_25px_rgba(0,255,255,0.6)] border-cyan-400' : 'opacity-60 border-gray-600'}`}>
                            <div className={`w-3 h-3 rounded-full ${autoPilot ? 'bg-cyan-400 animate-pulse shadow-[0_0_15px_#0ff]' : 'bg-gray-600'}`} />
                            <button 
                                onClick={toggleAutoPilot}
                                className="text-cyan-400 font-bold text-sm tracking-widest hover:text-white transition-colors"
                            >
                                {autoPilot ? 'AUTO-PILOT ACTIVE' : 'ENGAGE AUTO-PILOT'}
                            </button>
                         </div>
                    )}
                </div>

                <div className="text-right">
                    <div className="text-cyan-400 text-sm font-bold tracking-widest neon-text">SCORE</div>
                    <div className="text-4xl font-black text-white neon-text">{score.toString().padStart(6, '0')}</div>
                </div>
            </div>

            {/* Menus */}
            {gameState === GameState.MENU && (
                <div className="absolute inset-0 flex flex-col items-center justify-center bg-black/80 backdrop-blur-sm z-20">
                    <h1 className="text-6xl md:text-8xl font-black text-white mb-2 neon-text tracking-tighter italic transform -skew-x-12">
                        NEON<span className="text-pink-500 neon-text-pink">RUNNER</span>
                    </h1>
                    <p className="text-cyan-200 mb-8 text-lg tracking-widest opacity-80">INFINITE CITY PROTOCOL</p>
                    
                    <button 
                        onClick={startGame}
                        className="group relative px-12 py-4 bg-transparent overflow-hidden rounded-full border border-cyan-500 hover:border-pink-500 transition-colors duration-300"
                    >
                        <div className="absolute inset-0 w-full h-full bg-cyan-500/20 group-hover:bg-pink-500/20 transition-colors duration-300 blur-md"></div>
                        <span className="relative text-2xl font-bold text-white tracking-widest group-hover:neon-text-pink">INITIATE RUN</span>
                    </button>

                    <div className="mt-12 flex gap-4 text-gray-500 text-sm">
                        <span className="border border-gray-700 px-3 py-1 rounded">WASD / ARROWS</span>
                        <span className="border border-gray-700 px-3 py-1 rounded">SPACE TO JUMP</span>
                        <span className="border border-gray-700 px-3 py-1 rounded">SWIPE TO MOVE</span>
                    </div>
                </div>
            )}

            {gameState === GameState.GAME_OVER && (
                <div className="absolute inset-0 flex flex-col items-center justify-center bg-red-900/40 backdrop-blur-md z-20">
                    <h2 className="text-7xl font-black text-red-500 mb-4 shadow-red-500 drop-shadow-[0_0_30px_rgba(255,0,0,0.8)] italic">CRASHED</h2>
                    <div className="text-white text-2xl mb-8">
                        FINAL SCORE: <span className="text-yellow-400 font-mono font-bold">{finalScore}</span>
                    </div>
                    <button 
                        onClick={startGame}
                        className="px-10 py-3 bg-white text-black font-bold text-xl rounded-full hover:bg-cyan-400 hover:scale-105 transition-all shadow-[0_0_20px_rgba(255,255,255,0.4)]"
                    >
                        RETRY
                    </button>
                </div>
            )}
            
            {/* Mobile Controls Hint (Visible only when playing) */}
            {gameState === GameState.PLAYING && (
                <div className="absolute bottom-8 w-full text-center text-white/30 text-xs pointer-events-none md:hidden">
                    SWIPE TO CONTROL
                </div>
            )}
        </div>
    );
}
```
```
import * as THREE from 'three';
import { GameState, CollisionType, GameConfig, AIState } from './types';

interface LaneAnalysis {
    lane: number;
    isDeadly: boolean; // Solid obstacle ahead
    isBlockedSide: boolean; // Solid obstacle RIGHT HERE (Overlap)
    action: 'none' | 'jump' | 'duck'; // Action required to survive
    score: number; // Higher is better
    distanceToThreat: number;
    threatType: CollisionType | 'none';
    firstSolidDist: number; // Distance to absolute block ahead
}

export class GameEngine {
    private scene: THREE.Scene;
    private camera: THREE.PerspectiveCamera;
    private renderer: THREE.WebGLRenderer;
    private container: HTMLElement;
    
    // Game Objects
    private player: THREE.Group | null = null;
    private groundSegments: THREE.Object3D[] = [];
    private obstacles: THREE.Group[] = [];
    private particles: THREE.Mesh[] = [];
    private glitterSystem: THREE.Points | null = null;

    // Resources (Textures/Materials)
    private buildingTextures: THREE.CanvasTexture[] = [];
    private roadMaterial: THREE.MeshStandardMaterial | null = null;
    private sidewalkMaterial: THREE.MeshStandardMaterial | null = null;
    private treeMaterial: THREE.MeshStandardMaterial | null = null;

    // State
    public state: GameState = GameState.MENU;
    private animationId: number = 0;
    private score: number = 0;
    private distanceTraveled: number = 0;
    private gameSpeed: number = 0;
    
    // Configuration
    private config: GameConfig = {
        laneWidth: 4,
        startSpeed: 0.6,
        maxSpeed: 2.8, 
        speedIncrement: 0.0002, 
        jumpForce: 0.38,
        gravity: 0.020,
        visibilityRange: 350, 
        fogDensity: 0.008
    };

    // Player Physics
    private currentLane: number = 0;
    private targetX: number = 0;
    private playerVelocityY: number = 0;
    private isJumping: boolean = false;
    private isRolling: boolean = false;
    private rollTimer: number = 0;
    private playerBaseY: number = 1;
    
    // AI / Auto Pilot
    public autoPilotEnabled: boolean = false;
    private lastSafeLane: number = 0; 
    private aiLaneChangeCooldown: number = 0;

    // Callbacks
    private onScoreChange: (score: number) => void;
    private onGameOver: (finalScore: number) => void;
    private onAIUpdate: (state: AIState) => void;

    constructor(
        container: HTMLElement, 
        onScoreChange: (s: number) => void, 
        onGameOver: (s: number) => void,
        onAIUpdate: (state: AIState) => void
    ) {
        this.container = container;
        this.onScoreChange = onScoreChange;
        this.onGameOver = onGameOver;
        this.onAIUpdate = onAIUpdate;

        // Init THREE
        this.scene = new THREE.Scene();
        const fogColor = new THREE.Color(0x020205);
        this.scene.background = fogColor;
        this.scene.fog = new THREE.FogExp2(0x020205, this.config.fogDensity);

        this.camera = new THREE.PerspectiveCamera(60, window.innerWidth / window.innerHeight, 0.1, 400);
        this.camera.position.set(0, 6, 14);
        this.camera.lookAt(0, 2, -10);

        this.renderer = new THREE.WebGLRenderer({ antialias: true, powerPreference: "high-performance" });
        this.renderer.setSize(window.innerWidth, window.innerHeight);
        this.renderer.shadowMap.enabled = true;
        this.renderer.shadowMap.type = THREE.PCFSoftShadowMap;
        this.renderer.toneMapping = THREE.ACESFilmicToneMapping;
        this.renderer.toneMappingExposure = 1.2;
        container.appendChild(this.renderer.domElement);

        this.initMaterials();
        this.setupLights();
        this.createPlayer();
        this.createInitialWorld();
        this.createGlitter();

        window.addEventListener('resize', this.onResize.bind(this));
    }

    private initMaterials() {
        this.buildingTextures = [
            this.generateBuildingTexture(0),
            this.generateBuildingTexture(1),
            this.generateBuildingTexture(2)
        ];

        this.roadMaterial = new THREE.MeshStandardMaterial({
            color: 0x111111,
            roughness: 0.2,
            metalness: 0.6,
            dithering: true
        });

        this.sidewalkMaterial = new THREE.MeshStandardMaterial({
            color: 0x333333,
            roughness: 0.9,
            metalness: 0.1
        });

        this.treeMaterial = new THREE.MeshStandardMaterial({
            color: 0x2d4c1e,
            roughness: 0.8,
            emissive: 0x001100
        });
    }

    private generateBuildingTexture(variant: number): THREE.CanvasTexture {
        const canvas = document.createElement('canvas');
        canvas.width = 256;
        canvas.height = 512;
        const ctx = canvas.getContext('2d')!;
        
        ctx.fillStyle = variant === 0 ? '#050510' : (variant === 1 ? '#0a0a15' : '#000505');
        ctx.fillRect(0, 0, 256, 512);

        const windowColor = variant === 0 ? '#00ffff' : (variant === 1 ? '#ff00ff' : '#ffffff');
        for (let y = 0; y < 512; y += 20) {
            if (Math.random() > 0.8) continue;
            for (let x = 10; x < 246; x += 30) {
                if (Math.random() > 0.4) {
                    ctx.fillStyle = windowColor;
                    ctx.globalAlpha = 0.8 + Math.random() * 0.2;
                    ctx.fillRect(x, y, 20, 12);
                } else {
                    ctx.fillStyle = '#111122';
                    ctx.globalAlpha = 1;
                    ctx.fillRect(x, y, 20, 12);
                }
            }
        }
        
        const tex = new THREE.CanvasTexture(canvas);
        tex.magFilter = THREE.NearestFilter;
        tex.minFilter = THREE.LinearFilter;
        return tex;
    }

    private setupLights() {
        const ambientLight = new THREE.AmbientLight(0x404060, 1.5);
        this.scene.add(ambientLight);

        const dirLight = new THREE.DirectionalLight(0xaaccff, 2);
        dirLight.position.set(-20, 50, 10);
        dirLight.castShadow = true;
        dirLight.shadow.mapSize.width = 2048;
        dirLight.shadow.mapSize.height = 2048;
        dirLight.shadow.bias = -0.0001;
        this.scene.add(dirLight);
    }

    private createGlitter() {
        const count = 2000;
        const geom = new THREE.BufferGeometry();
        const positions = new Float32Array(count * 3);
        const velocities = new Float32Array(count);
        
        for(let i=0; i<count; i++) {
            positions[i*3] = (Math.random() - 0.5) * 150;
            positions[i*3+1] = Math.random() * 60;
            positions[i*3+2] = -Math.random() * 100;
            velocities[i] = 0.5 + Math.random();
        }
        
        geom.setAttribute('position', new THREE.BufferAttribute(positions, 3));
        geom.setAttribute('velocity', new THREE.BufferAttribute(velocities, 1));

        const mat = new THREE.PointsMaterial({
            color: 0x88ccff,
            size: 0.15,
            transparent: true,
            opacity: 0.6,
            blending: THREE.AdditiveBlending
        });
        
        this.glitterSystem = new THREE.Points(geom, mat);
        this.scene.add(this.glitterSystem);
    }

    private createPlayer() {
        this.player = new THREE.Group();

        const bodyMat = new THREE.MeshStandardMaterial({ 
            color: 0x111111, 
            roughness: 0.2, 
            metalness: 1.0,
            envMapIntensity: 1.0
        });
        
        const accentMat = new THREE.MeshStandardMaterial({
            color: 0x00ffff,
            emissive: 0x00ffff,
            emissiveIntensity: 2
        });

        const engineGlowMat = new THREE.MeshBasicMaterial({ color: 0xff00ff });

        const fuselage = new THREE.Mesh(new THREE.CapsuleGeometry(0.35, 1.2, 4, 8), bodyMat);
        fuselage.rotation.x = Math.PI / 2;
        fuselage.position.y = 0.5;
        fuselage.castShadow = true;
        this.player.add(fuselage);

        const cowl = new THREE.Mesh(new THREE.BoxGeometry(0.7, 0.4, 0.8), bodyMat);
        cowl.position.set(0, 0.6, -0.5);
        cowl.castShadow = true;
        this.player.add(cowl);

        const windshield = new THREE.Mesh(new THREE.BoxGeometry(0.68, 0.1, 0.5), accentMat);
        windshield.position.set(0, 0.8, -0.4);
        windshield.rotation.x = -0.2;
        this.player.add(windshield);

        const engineL = new THREE.Mesh(new THREE.CylinderGeometry(0.15, 0.25, 0.6, 16), bodyMat);
        engineL.rotation.x = Math.PI / 2;
        engineL.position.set(-0.3, 0.4, 0.7);
        this.player.add(engineL);
        
        const engineR = engineL.clone();
        engineR.position.set(0.3, 0.4, 0.7);
        this.player.add(engineR);

        const glowL = new THREE.Mesh(new THREE.CircleGeometry(0.12, 8), engineGlowMat);
        glowL.rotation.x = Math.PI; 
        glowL.position.set(-0.3, 0.4, 1.01);
        this.player.add(glowL);
        const glowR = glowL.clone();
        glowR.position.set(0.3, 0.4, 1.01);
        this.player.add(glowR);

        const finL = new THREE.Mesh(new THREE.BoxGeometry(0.05, 0.4, 0.8), bodyMat);
        finL.position.set(-0.5, 0.3, 0.5);
        finL.rotation.z = 0.3;
        finL.castShadow = true;
        this.player.add(finL);
        
        const finR = finL.clone();
        finR.position.set(0.5, 0.3, 0.5);
        finR.rotation.z = -0.3;
        finR.castShadow = true;
        this.player.add(finR);

        const underglow = new THREE.Mesh(new THREE.PlaneGeometry(1.5, 2.5), 
            new THREE.MeshBasicMaterial({ color: 0x00ffff, transparent: true, opacity: 0.2, side: THREE.DoubleSide }));
        underglow.rotation.x = -Math.PI / 2;
        underglow.position.y = 0.05;
        this.player.add(underglow);

        this.player.position.set(0, 1, 0);
        this.scene.add(this.player);
    }

    private createInitialWorld() {
        for (let i = 0; i < 25; i++) {
            this.spawnGroundSegment(-i * 10);
        }
    }

    private spawnGroundSegment(z: number) {
        const segmentGroup = new THREE.Group();
        segmentGroup.position.z = z;

        const road = new THREE.Mesh(
            new THREE.PlaneGeometry(14, 10),
            this.roadMaterial!
        );
        road.rotation.x = -Math.PI / 2;
        road.receiveShadow = true;
        segmentGroup.add(road);

        const laneMat = new THREE.MeshBasicMaterial({ color: 0x00ffff });
        const lineL = new THREE.Mesh(new THREE.PlaneGeometry(0.15, 10), laneMat);
        lineL.rotation.x = -Math.PI / 2;
        lineL.position.set(-this.config.laneWidth / 2, 0.02, 0);
        segmentGroup.add(lineL);

        const lineR = new THREE.Mesh(new THREE.PlaneGeometry(0.15, 10), laneMat);
        lineR.rotation.x = -Math.PI / 2;
        lineR.position.set(this.config.laneWidth / 2, 0.02, 0);
        segmentGroup.add(lineR);

        const sidewalkGeo = new THREE.BoxGeometry(4, 0.4, 10);
        
        const swL = new THREE.Mesh(sidewalkGeo, this.sidewalkMaterial!);
        swL.position.set(-9, 0.2, 0);
        swL.receiveShadow = true;
        segmentGroup.add(swL);
        
        const swR = new THREE.Mesh(sidewalkGeo, this.sidewalkMaterial!);
        swR.position.set(9, 0.2, 0);
        swR.receiveShadow = true;
        segmentGroup.add(swR);

        if (Math.random() < 0.33) {
            this.spawnStreetLamp(-8, 0, segmentGroup);
            this.spawnStreetLamp(8, 0, segmentGroup);
        }

        if (Math.random() < 0.5) {
             this.spawnTree(-10, Math.random() * 4 - 2, segmentGroup);
             this.spawnTree(10, Math.random() * 4 - 2, segmentGroup);
        }

        if (Math.random() > 0.1) {
            this.spawnBuilding(-16 - Math.random()*2, 0, segmentGroup);
            this.spawnBuilding(16 + Math.random()*2, 0, segmentGroup);
        }

        this.scene.add(segmentGroup);
        this.groundSegments.push(segmentGroup);
    }

    private spawnStreetLamp(x: number, z: number, parent: THREE.Group) {
        const poleMat = new THREE.MeshStandardMaterial({ color: 0x111111, metalness: 0.8, roughness: 0.2 });
        const bulbMat = new THREE.MeshBasicMaterial({ color: 0xffaa00 });

        const group = new THREE.Group();
        group.position.set(x, 0, z);

        const pole = new THREE.Mesh(new THREE.CylinderGeometry(0.1, 0.15, 6), poleMat);
        pole.position.y = 3;
        pole.castShadow = true;
        group.add(pole);

        const arm = new THREE.Mesh(new THREE.BoxGeometry(1.5, 0.1, 0.1), poleMat);
        arm.position.set(x > 0 ? -0.75 : 0.75, 6, 0);
        group.add(arm);

        const head = new THREE.Mesh(new THREE.BoxGeometry(0.4, 0.2, 0.3), poleMat);
        head.position.set(x > 0 ? -1.5 : 1.5, 5.9, 0);
        group.add(head);

        const bulb = new THREE.Mesh(new THREE.BoxGeometry(0.2, 0.05, 0.2), bulbMat);
        bulb.position.set(x > 0 ? -1.5 : 1.5, 5.8, 0);
        group.add(bulb);

        const spot = new THREE.SpotLight(0xffaa00, 10, 20, 0.6, 0.5, 1);
        spot.position.set(x > 0 ? -1.5 : 1.5, 5.8, 0);
        spot.target.position.set(x > 0 ? -1.5 : 1.5, 0, 0);
        spot.castShadow = false; 
        group.add(spot);
        group.add(spot.target);

        parent.add(group);
    }

    private spawnTree(x: number, z: number, parent: THREE.Group) {
        const trunkGeo = new THREE.CylinderGeometry(0.2, 0.3, 1.5, 6);
        const trunkMat = new THREE.MeshStandardMaterial({ color: 0x3d2817, roughness: 1.0 });
        const leavesGeo = new THREE.IcosahedronGeometry(1.2, 0);

        const tree = new THREE.Group();
        tree.position.set(x, 0, z);

        const trunk = new THREE.Mesh(trunkGeo, trunkMat);
        trunk.position.y = 0.75;
        trunk.castShadow = true;
        tree.add(trunk);

        const leaves = new THREE.Mesh(leavesGeo, this.treeMaterial!);
        leaves.position.y = 2.2;
        leaves.castShadow = true;
        tree.add(leaves);

        parent.add(tree);
    }

    private spawnBuilding(x: number, z: number, parent: THREE.Group) {
        const h = 15 + Math.random() * 35;
        const w = 6 + Math.random() * 6;
        const d = 6 + Math.random() * 6;
        
        const texIndex = Math.floor(Math.random() * this.buildingTextures.length);
        const mat = new THREE.MeshStandardMaterial({ 
            map: this.buildingTextures[texIndex],
            roughness: 0.3,
            metalness: 0.1
        });

        const building = new THREE.Mesh(new THREE.BoxGeometry(w, h, d), mat);
        building.position.set(x, h / 2, z);
        building.castShadow = true;
        parent.add(building);

        if (Math.random() > 0.5) {
            const antH = 2 + Math.random() * 5;
            const antenna = new THREE.Mesh(
                new THREE.CylinderGeometry(0.1, 0.2, antH),
                new THREE.MeshStandardMaterial({ color: 0x444444 })
            );
            antenna.position.y = h/2 + antH/2;
            building.add(antenna);
            
            const blinker = new THREE.Mesh(new THREE.SphereGeometry(0.2), new THREE.MeshBasicMaterial({ color: 0xff0000 }));
            blinker.position.y = antH/2;
            antenna.add(blinker);
        }
    }

    // --- OBSTACLE & SPAWNING ---
    private spawnObstacleRow(z: number) {
        const possibleLanes = [this.lastSafeLane];
        if (this.lastSafeLane > -1) possibleLanes.push(this.lastSafeLane - 1);
        if (this.lastSafeLane < 1) possibleLanes.push(this.lastSafeLane + 1);

        const safeLaneIdx = possibleLanes[Math.floor(Math.random() * possibleLanes.length)];
        this.lastSafeLane = safeLaneIdx; 

        [-1, 0, 1].forEach(laneIdx => {
            const x = laneIdx * this.config.laneWidth;
            if (laneIdx === safeLaneIdx) {
                if (Math.random() < 0.3) this.spawnCoin(x, z, laneIdx);
            } else {
                if (Math.random() < 0.8) this.createObstacleAt(x, z, laneIdx);
            }
        });
    }

    private createObstacleAt(x: number, z: number, laneIdx: number) {
        const typeRand = Math.random();
        const obsGroup = new THREE.Group();
        obsGroup.position.set(x, 0, z);
        obsGroup.userData = { active: true, lane: laneIdx };

        const techMat = new THREE.MeshStandardMaterial({ color: 0x222222, roughness: 0.4, metalness: 0.8 });
        const hazardMat = new THREE.MeshStandardMaterial({ color: 0xff3300, emissive: 0xff0000, emissiveIntensity: 0.5 });
        const glassMat = new THREE.MeshPhysicalMaterial({ 
            color: 0x88ccff, transmission: 0.9, opacity: 1, transparent: true, roughness: 0, metalness: 0 
        });

        if (typeRand < 0.25) {
            // JUMP (Energy Barrier) - Must Jump OVER
            obsGroup.userData.collisionType = CollisionType.JUMP;
            
            const base = new THREE.Mesh(new THREE.BoxGeometry(3.5, 0.5, 0.5), techMat);
            base.position.y = 0.25;
            obsGroup.add(base);
            
            // Energy Field
            const field = new THREE.Mesh(new THREE.BoxGeometry(3.3, 0.8, 0.1), glassMat);
            field.position.y = 0.9;
            obsGroup.add(field);
            
            const top = new THREE.Mesh(new THREE.BoxGeometry(3.5, 0.2, 0.2), hazardMat);
            top.position.y = 1.4;
            obsGroup.add(top);

        } else if (typeRand < 0.5) {
            // DUCK (Overhead Pipe/Drone) - Must Roll UNDER
            obsGroup.userData.collisionType = CollisionType.DUCK;
            
            const droneBody = new THREE.Mesh(new THREE.BoxGeometry(3.8, 1, 1), techMat);
            droneBody.position.y = 3.0;
            droneBody.castShadow = true;
            obsGroup.add(droneBody);

            const l1 = new THREE.Mesh(new THREE.SphereGeometry(0.2), hazardMat);
            l1.position.set(-1.5, 3, 0.6);
            obsGroup.add(l1);
            const l2 = l1.clone();
            l2.position.set(1.5, 3, 0.6);
            obsGroup.add(l2);

            const p1 = new THREE.Mesh(new THREE.CylinderGeometry(0.1, 0.1, 4), techMat);
            p1.position.set(-1.8, 2, 0);
            obsGroup.add(p1);
            const p2 = p1.clone();
            p2.position.set(1.8, 2, 0);
            obsGroup.add(p2);

        } else {
            // SOLID (Data Wall) - Must Dodge
            obsGroup.userData.collisionType = CollisionType.SOLID;
            
            const mesh = new THREE.Mesh(new THREE.BoxGeometry(3.6, 4, 3.6), techMat);
            mesh.position.y = 2;
            mesh.castShadow = true;
            obsGroup.add(mesh);

            const screen = new THREE.Mesh(new THREE.PlaneGeometry(2.5, 2.5), new THREE.MeshBasicMaterial({ color: 0xff0000 }));
            screen.position.set(0, 2.5, 1.81);
            obsGroup.add(screen);
        }

        this.scene.add(obsGroup);
        this.obstacles.push(obsGroup);
    }

    private spawnCoin(x: number, z: number, laneIdx: number) {
        const coin = new THREE.Mesh(
            new THREE.OctahedronGeometry(0.5, 0),
            new THREE.MeshBasicMaterial({ color: 0xffd700, wireframe: true })
        );
        const inner = new THREE.Mesh(
            new THREE.OctahedronGeometry(0.3, 0),
            new THREE.MeshBasicMaterial({ color: 0xffaa00 })
        );
        coin.add(inner);

        coin.position.set(x, 1.5, z);
        coin.userData = { active: true, collisionType: CollisionType.COIN, lane: laneIdx };
        this.scene.add(coin);
        this.obstacles.push(coin as any);
    }

    // --- GAME LOOP ---

    public start() {
        if (this.state === GameState.PLAYING) return;
        
        this.score = 0;
        this.distanceTraveled = 0;
        this.gameSpeed = this.config.startSpeed;
        this.currentLane = 0;
        this.lastSafeLane = 0;
        this.playerVelocityY = 0;
        this.isJumping = false;
        this.isRolling = false;
        this.aiLaneChangeCooldown = 0;
        
        this.obstacles.forEach(o => this.scene.remove(o));
        this.obstacles = [];
        this.particles.forEach(p => this.scene.remove(p));
        this.particles = [];
        
        if (this.player) {
            this.player.position.set(0, 1, 0);
            this.player.visible = true;
            this.player.rotation.set(0, 0, 0);
        }

        this.state = GameState.PLAYING;
        this.animate();
    }

    private animate = () => {
        if (this.state !== GameState.PLAYING) return;
        this.animationId = requestAnimationFrame(this.animate);
        this.update();
        this.renderer.render(this.scene, this.camera);
    }

    private update() {
        this.gameSpeed = Math.min(this.config.maxSpeed, this.gameSpeed + this.config.speedIncrement);
        this.distanceTraveled += this.gameSpeed;
        this.score = Math.floor(this.distanceTraveled * 10);
        this.onScoreChange(this.score);

        if (this.autoPilotEnabled) this.updateAI();

        // --- PHYSICS ---
        this.targetX = this.currentLane * this.config.laneWidth;
        if (this.player) {
            // Anti-Hover: fast snap for AI
            const lerpFactor = this.autoPilotEnabled ? 0.8 : 0.3; 
            
            this.player.position.x += (this.targetX - this.player.position.x) * lerpFactor;

            if (this.autoPilotEnabled && Math.abs(this.player.position.x - this.targetX) < 0.2) {
                this.player.position.x = this.targetX;
            } else if (!this.autoPilotEnabled && Math.abs(this.player.position.x - this.targetX) < 0.05) {
                this.player.position.x = this.targetX;
            }

            const targetLean = (this.targetX - this.player.position.x) * -0.15;
            this.player.rotation.z += (targetLean - this.player.rotation.z) * 0.1;

            if (this.isJumping) {
                this.player.position.y += this.playerVelocityY;
                this.playerVelocityY -= this.config.gravity;
                this.player.rotation.x = -0.2; 

                if (this.player.position.y <= this.playerBaseY) {
                    this.player.position.y = this.playerBaseY;
                    this.isJumping = false;
                    this.playerVelocityY = 0;
                    this.player.rotation.x = 0;
                    this.createExplosion(this.player.position, 0x00ffff, 5); 
                }
            } else {
                this.player.rotation.x = 0;
                if (this.isRolling) {
                    this.rollTimer--;
                    this.player.scale.y = 0.6; 
                    if (this.rollTimer <= 0) {
                        this.isRolling = false;
                        this.player.scale.y = 1;
                    }
                }
            }
        }

        if (this.player) {
            this.camera.position.x += (this.player.position.x * 0.6 - this.camera.position.x) * 0.1;
        }

        this.groundSegments.forEach(g => {
            g.position.z += this.gameSpeed;
            if (g.position.z > 15) { 
                g.position.z -= 250; 
            }
        });

        if (this.glitterSystem) {
            const positions = this.glitterSystem.geometry.attributes.position.array as Float32Array;
            const velocities = this.glitterSystem.geometry.attributes.velocity.array as Float32Array;
            for(let i=0; i < positions.length; i+=3) {
                positions[i+1] -= velocities[i/3]; 
                positions[i+2] += this.gameSpeed * 1.2; 

                if (positions[i+1] < 0 || positions[i+2] > 5) {
                    positions[i+1] = 40 + Math.random() * 20;
                    positions[i+2] = -50 - Math.random() * 50;
                    positions[i] = (Math.random() - 0.5) * 120;
                }
            }
            this.glitterSystem.geometry.attributes.position.needsUpdate = true;
        }

        // Obstacles
        for (let i = this.obstacles.length - 1; i >= 0; i--) {
            const obs = this.obstacles[i];
            obs.position.z += this.gameSpeed;
            
            if (obs.userData.collisionType === CollisionType.COIN) {
                obs.rotation.y += 0.05;
                obs.rotation.x += 0.02;
            }

            if (this.player && obs.userData.active) {
                const dx = Math.abs(obs.position.x - this.player.position.x);
                const dz = obs.position.z; 

                // Precise hitboxes
                if (dz > -1.0 && dz < 1.0 && dx < 1.2) {
                    if (obs.userData.collisionType === CollisionType.COIN) {
                        this.score += 500;
                        this.createExplosion(obs.position, 0xffff00, 10);
                        obs.userData.active = false;
                        obs.visible = false;
                    } else {
                        let safe = false;
                        // RULES OF SURVIVAL
                        // 1. Solid: NEVER safe.
                        // 2. Jump: Safe only if Y > 1.2
                        // 3. Duck: Safe only if rolling
                        
                        if (obs.userData.collisionType === CollisionType.JUMP && this.player.position.y > 1.2) {
                            safe = true;
                        }
                        else if (obs.userData.collisionType === CollisionType.DUCK && this.isRolling) {
                            safe = true;
                        }
                        
                        // NO AUTO-PILOT CHEATS. If not safe, you die.
                        if (!safe) {
                            this.gameOver();
                        }
                    }
                }
            }

            if (obs.position.z > 15) {
                this.scene.remove(obs);
                this.obstacles.splice(i, 1);
            }
        }

        const spawnZ = -180; 
        const minGap = 50 + (this.gameSpeed * 30); 
        const lastObs = this.obstacles[this.obstacles.length - 1];
        
        if (!lastObs || lastObs.position.z > (spawnZ + minGap)) {
            this.spawnObstacleRow(spawnZ);
        }

        this.updateParticles();
    }

    // --- AI LOGIC ---
    private updateAI() {
        if (!this.player) return;

        if (this.aiLaneChangeCooldown > 0) this.aiLaneChangeCooldown--;

        const currentSpeed = this.gameSpeed;
        const visionRange = 800 + (currentSpeed * 400); 

        const analysis = [-1, 0, 1].map(l => this.analyzeLane(l, visionRange));
        const currentLaneStats = analysis.find(a => a.lane === this.currentLane)!;

        // GLOBAL PATHFINDING
        const bestLaneAnalysis = analysis.sort((a,b) => b.score - a.score)[0];
        
        let targetLane = this.currentLane;
        let aiAction: AIState['action'] = 'SCANNING';
        let isEmergency = false;

        // Threshold for imminent impact
        if (currentLaneStats.firstSolidDist < (100 + currentSpeed * 20)) {
            isEmergency = true;
            this.aiLaneChangeCooldown = 0;
        }

        if (isEmergency) {
            if (bestLaneAnalysis.lane !== this.currentLane) {
                const diff = bestLaneAnalysis.lane - this.currentLane;
                const direction = diff > 0 ? 1 : -1;
                const nextStepLane = this.currentLane + direction;

                const nextStepAnalysis = analysis.find(a => a.lane === nextStepLane)!;
                
                // CRITICAL SAFETY CHECK:
                // 1. Is the side lane BLOCKED right now? (Side Swipe Protection)
                if (!nextStepAnalysis.isBlockedSide) {
                    
                    // 2. Forward safety:
                    // Only move if it's safe OR if it's safer than staying (Panic Squeeze).
                    // If next lane has a wall further away than current wall, take it.
                    const isSafer = nextStepAnalysis.firstSolidDist > 20 && 
                                   (nextStepAnalysis.firstSolidDist > currentLaneStats.firstSolidDist);

                    // Or if it is completely safe
                    const isSafe = nextStepAnalysis.firstSolidDist > 30;

                    if (isSafe || isSafer) {
                        targetLane = nextStepLane;
                        aiAction = 'DODGE';
                    }
                } else {
                    // Side is blocked. We MUST wait.
                    // Hopefully we can jump/duck the current obstacle until side clears.
                    aiAction = 'SCANNING'; // Holding pattern
                }
            }
        } else {
             // Optimize for coins/safety if not urgent
             if (this.aiLaneChangeCooldown <= 0) {
                 if (bestLaneAnalysis.score > currentLaneStats.score + 50 && bestLaneAnalysis.firstSolidDist > 300) {
                     // Ensure we don't switch into a side-block even in non-emergency
                     const targetStats = analysis.find(a => a.lane === bestLaneAnalysis.lane)!;
                     if (!targetStats.isBlockedSide) {
                        targetLane = bestLaneAnalysis.lane;
                        aiAction = 'RUN';
                        this.aiLaneChangeCooldown = 20;
                     }
                 }
             }
        }

        if (targetLane !== this.currentLane) {
            this.setLane(targetLane);
        }

        // --- ACTION EXECUTION ---
        const effectiveLaneStats = analysis.find(a => a.lane === this.currentLane)!; 

        if (effectiveLaneStats.action !== 'none') {
            const dist = effectiveLaneStats.distanceToThreat;
            const timeToImpactFrames = dist / this.gameSpeed;

            if (effectiveLaneStats.action === 'jump') {
                if (timeToImpactFrames < 25 && timeToImpactFrames > 5) { 
                    this.jump();
                    aiAction = 'JUMP';
                }
            } else if (effectiveLaneStats.action === 'duck') {
                if (timeToImpactFrames < 25 && timeToImpactFrames > 5) {
                    this.roll();
                    aiAction = 'DUCK';
                }
            }
        }

        this.onAIUpdate({
            enabled: this.autoPilotEnabled,
            currentLane: this.currentLane,
            targetLane: targetLane,
            action: aiAction,
            confidence: isEmergency ? 20 : 100,
            nearestThreatDist: Math.floor(currentLaneStats.distanceToThreat),
            laneScores: analysis.sort((a,b) => a.lane - b.lane).map(a => a.score)
        });
    }

    private analyzeLane(laneIdx: number, range: number): LaneAnalysis {
        let isDeadly = false;
        let isBlockedSide = false;
        let action: 'none' | 'jump' | 'duck' = 'none';
        let score = 5000;
        let distToThreat = 9999;
        let firstSolidDist = 9999;
        let threatType: CollisionType | 'none' = 'none';

        const laneObs = this.obstacles.filter(o => 
            o.userData.active && 
            o.userData.lane === laneIdx && 
            o.position.z > -range && 
            o.position.z < 10 // Look further back (10 units) to catch passing obstacles
        );
        
        laneObs.sort((a, b) => b.position.z - a.position.z);

        for (const obs of laneObs) {
            const type = obs.userData.collisionType as CollisionType;
            const z = obs.position.z;
            const dist = Math.abs(z); 

            // SIDE SWIPE CHECK:
            // Player is roughly at Z=0. Objects move +Z.
            // If object is between -4 (approaching) and +5 (passed but close), 
            // the side is blocked.
            if (z > -4 && z < 5) {
                if (type !== CollisionType.COIN) {
                    isBlockedSide = true;
                    score = -999999; // Impossible lane
                }
            }

            if (type === CollisionType.COIN) {
                score += 50; 
            } else {
                // Only consider threats IN FRONT for timing
                if (z < 0) { 
                     if (dist < distToThreat) {
                        distToThreat = dist;
                        threatType = type;
                    }

                    if (type === CollisionType.SOLID) {
                        isDeadly = true;
                        if (dist < firstSolidDist) firstSolidDist = dist;
                        score -= (100000 / (dist + 1));
                    } 
                    else if (type === CollisionType.JUMP) {
                        if (action === 'none') action = 'jump'; 
                        score -= 100;
                        if (this.isRolling && dist < 30) score -= 5000;
                    } 
                    else if (type === CollisionType.DUCK) {
                        if (action === 'none') action = 'duck';
                        score -= 100;
                        if (this.isJumping && dist < 30) score -= 5000;
                    }
                }
            }
        }

        if (laneIdx === 0) score += 10;

        return { lane: laneIdx, isDeadly, isBlockedSide, action, score, distanceToThreat: distToThreat, threatType, firstSolidDist };
    }

    // --- CONTROLS & HELPERS ---
    public moveLeft() { if (this.currentLane > -1) this.currentLane--; }
    public moveRight() { if (this.currentLane < 1) this.currentLane++; }
    public setLane(l: number) { this.currentLane = l; }
    public jump() {
        if (!this.isJumping) {
            this.isJumping = true;
            this.playerVelocityY = this.config.jumpForce;
            this.isRolling = false;
        }
    }
    public roll() {
        if (!this.isJumping && !this.isRolling) {
            this.isRolling = true;
            this.rollTimer = 40;
        }
    }
    public toggleAutoPilot(v: boolean) {
        this.autoPilotEnabled = v;
        if (!v && this.player) {
            this.player.rotation.z = 0;
            this.player.visible = true;
        }
    }

    private createExplosion(pos: THREE.Vector3, color: number, count: number) {
        for (let i = 0; i < count; i++) {
            const geo = new THREE.BoxGeometry(0.1, 0.1, 0.1);
            const mat = new THREE.MeshBasicMaterial({ color });
            const m = new THREE.Mesh(geo, mat);
            m.position.copy(pos);
            m.userData = {
                vel: new THREE.Vector3((Math.random()-0.5), (Math.random()-0.5)+0.5, (Math.random()-0.5)),
                life: 1.0
            };
            this.scene.add(m);
            this.particles.push(m);
        }
    }

    private updateParticles() {
        for (let i = this.particles.length - 1; i >= 0; i--) {
            const p = this.particles[i];
            p.userData.life -= 0.04;
            p.position.add(p.userData.vel);
            p.scale.setScalar(p.userData.life);
            if (p.userData.life <= 0) {
                this.scene.remove(p);
                this.particles.splice(i, 1);
            }
        }
    }

    private gameOver() {
        this.state = GameState.GAME_OVER;
        cancelAnimationFrame(this.animationId);
        if (this.player) this.createExplosion(this.player.position, 0xff0000, 50);
        if (this.player) this.player.visible = false;
        this.onGameOver(this.score);
    }

    private onResize() {
        this.camera.aspect = window.innerWidth / window.innerHeight;
        this.camera.updateProjectionMatrix();
        this.renderer.setSize(window.innerWidth, window.innerHeight);
    }

    public cleanup() {
        cancelAnimationFrame(this.animationId);
        window.removeEventListener('resize', this.onResize);
        if (this.container && this.renderer.domElement) {
            this.container.removeChild(this.renderer.domElement);
        }
    }
}
```
```
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0, maximum-scale=1.0, user-scalable=no">
    <title>Neon Runner</title>
    <script src="https://cdn.tailwindcss.com"></script>
    <link href="https://fonts.googleapis.com/css2?family=Orbitron:wght@400;700;900&family=Rajdhani:wght@500;700&display=swap" rel="stylesheet">
    <style>
        body {
            background-color: #050510;
            overflow: hidden;
            font-family: 'Rajdhani', sans-serif;
        }
        /* Custom Scrollbar for any overflow elements */
        ::-webkit-scrollbar {
            width: 6px;
        }
        ::-webkit-scrollbar-track {
            background: #111; 
        }
        ::-webkit-scrollbar-thumb {
            background: #00ffff; 
        }
        .neon-text {
            text-shadow: 0 0 10px rgba(0, 255, 255, 0.7), 0 0 20px rgba(0, 255, 255, 0.5);
        }
        .neon-text-pink {
            text-shadow: 0 0 10px rgba(255, 0, 255, 0.7), 0 0 20px rgba(255, 0, 255, 0.5);
        }
    </style>
<script type="importmap">
{
  "imports": {
    "three": "https://aistudiocdn.com/three@^0.181.2",
    "react-dom/": "https://aistudiocdn.com/react-dom@^19.2.0/",
    "react/": "https://aistudiocdn.com/react@^19.2.0/",
    "react": "https://aistudiocdn.com/react@^19.2.0"
  }
}
</script>
</head>
<body>
    <div id="root"></div>
</body>
</html>
```
```
import React from 'react';
import ReactDOM from 'react-dom/client';
import App from './App';

const rootElement = document.getElementById('root');
if (!rootElement) {
  throw new Error("Could not find root element to mount to");
}

const root = ReactDOM.createRoot(rootElement);
root.render(
  <React.StrictMode>
    <App />
  </React.StrictMode>
);
```
```

import * as THREE from 'three';

export enum GameState {
    MENU = 'MENU',
    PLAYING = 'PLAYING',
    GAME_OVER = 'GAME_OVER'
}

export enum CollisionType {
    SOLID = 'solid',
    JUMP = 'jump',
    DUCK = 'duck',
    COIN = 'coin'
}

export interface GameConfig {
    laneWidth: number;
    startSpeed: number;
    maxSpeed: number;
    speedIncrement: number;
    jumpForce: number;
    gravity: number;
    visibilityRange: number;
    fogDensity: number;
}

export interface PlayerState {
    lane: number;
    isJumping: boolean;
    isRolling: boolean;
    velocityY: number;
}

export interface AIState {
    enabled: boolean;
    currentLane: number;
    targetLane: number;
    action: 'RUN' | 'JUMP' | 'DUCK' | 'DODGE' | 'SCANNING';
    confidence: number; // 0-100
    nearestThreatDist: number;
    laneScores: number[];
}
```
