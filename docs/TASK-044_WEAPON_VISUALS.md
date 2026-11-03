# TASK-044 — Weapon visuals and remote equipment sync (development only)

Base: TASK-043 local development worktree `feature/TASK-040-multi-wolf-coop`. No release or production deployment.

- Added simple procedural held spear, bow and shield meshes, attached to KayKit right-hand BoneAttachment3D socket. These are placeholder shapes, not final game-ready weapon assets. Visible in the local character and on other connected clients.
- Server validates crafting/ownership before accepting equipped item and broadcasts the new visual state; late join receives equipment of all existing players. Clear equipment when disconnected; show/hide the existing axe when combat equipment changes.
- Bow now broadcasts a short cosmetic arrow tracer between the server-selected shooter and target; damage remains server-authoritative and instant. No true ballistic projectile, collision/line-of-sight check or player-directed aiming is implemented yet.
- Network E2E extended: dedicated WebSocket + two separate clients; medic observes remote shield equipment model; old raid rewards and combat retained. Local Godot import, TASK-042 crafting and TASK-043 weapon mechanics PASS.

Remaining: full target selection/aiming and line-of-sight, 3D weapon assets, mobile interaction usability and physical Android FPS/thermal testing. Do not call this complete bow combat.
