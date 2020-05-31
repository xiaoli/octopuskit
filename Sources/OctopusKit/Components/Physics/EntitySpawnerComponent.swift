//
//  EntitySpawnerComponent.swift
//  OctopusKit
//
//  Created by ShinryakuTako@invadingoctopus.io on 2018/06/05.
//  Copyright © 2020 Invading Octopus. Licensed under Apache License v2.0 (see LICENSE.txt)
//

import SpriteKit
import GameplayKit

/// Signals the entity of this component to spawn a new entity, in the direction of the entity's `NodeComponent` node, and applies the specified initial forces to the new entity's physics body if there is one.
///
/// This component may be used for launching projectiles (such as bullets or missiles) from a character or another onscreen object.
///
/// **Dependencies:** `NodeComponent`
open class EntitySpawnerComponent: OKComponent {

    // CHECK: Should this be named "Emitter" to be consistent with "Particle Emitter", or should this be named "Spawner" because that may be more accurate?
    
    open override var requiredComponents: [GKComponent.Type]? {
        [NodeComponent.self]
    }
    
    // TODO: Fix template copying.
    
    /// The entity to create copies of for every new spawn.
    open var spawnTemplate:     OKEntity?
    
    // TODO: CHECK: Mention whether it's the parent's center or anchorPoint.
    
    /// The position difference in relation to the parent entity's node for a newly spawned entity.
    ///
    /// For example, this may be used to spawn bullets from the tip of a gun's muzzle.
    open var positionOffset:    CGPoint
    
    /// The difference from the parent entity node's `zRotation` angle, in radians, for the new spawned entity's initial direction.
    ///
    /// For example, this may be used to simulate sparks flying in different directions.
    open var angleOffset:       CGFloat
    
    /// The distance from the spawning `position` in the direction of the `angleOffset`.
    ///
    /// For example, this may be used to spawn flames farther from a flaming object.
    open var distanceOffset:    CGFloat

    /// The initial impulse to apply to a newly spawned entity's `PhysicsComponent` body.
    open var initialImpulse:    CGFloat?
    
    /// The reverse impulse to apply to the **spawner (parent) entity's** `PhysicsComponent` body.
    ///
    /// This may be used to simulate recoil on characters firing weapons.
    open var recoilImpulse:     CGFloat?
    
    /// The `SKAction` to run on every newly spawned entity.
    open var actionOnSpawn:     SKAction?
    
    /// Logs debugging information if `true`.
    public var logSpawns:       Bool
    
    /// Creates an `EntitySpawnerComponent` that may add new entities to the entity's scene when `spawn()` is called. The default settings provided to this initializer may be optionally overridden for each individual `spawn()` call.
    /// - Parameters:
    ///   - spawnTemplate:  The entity to create copies of for every new spawn. Default: `nil`
    ///   - positionOffset: The position difference in relation to the parent entity's node for a newly spawned entity. Default: `(0,0)`
    ///   - angleOffset:    The difference from the parent entity node's `zRotation` angle, in radians, for the new spawned entity's initial direction. Default: `0`
    ///   - distanceOffset: The distance from the parent entity's node for a newly spawned entity's initial position. Default: `0`
    ///   - initialImpulse: The initial impulse to apply to a newly spawned entity's `PhysicsComponent` body. Default: `nil`
    ///   - recoilImpulse:  The reverse impulse to apply to the **spawner (parent) entity's** `PhysicsComponent` body. Default: `nil`
    ///   - actionOnSpawn:  The `SKAction` to run on every newly spawned entity. Default: `nil`
    ///   - logSpawns:      If `true`, debugging information is logged.
    public init(spawnTemplate:  OKEntity?   = nil,
                positionOffset: CGPoint     = .zero,
                angleOffset:    CGFloat     = 0,
                distanceOffset: CGFloat     = 0,
                initialImpulse: CGFloat?    = nil,
                recoilImpulse:  CGFloat?    = nil,
                actionOnSpawn:  SKAction?   = nil,
                logSpawns:      Bool        = false)
    {
        self.spawnTemplate  = spawnTemplate
        
        self.positionOffset = positionOffset
        self.angleOffset    = angleOffset
        self.distanceOffset = distanceOffset
        
        self.initialImpulse = initialImpulse
        self.recoilImpulse  = recoilImpulse
        
        self.actionOnSpawn  = actionOnSpawn
        self.logSpawns      = logSpawns
        
        super.init()
    }
    
    public required init?(coder aDecoder: NSCoder) { fatalError("init(coder:) has not been implemented") }
    
    /// Requests this component's entity's delegate (i.e. the scene) to spawn a new entity. You may selectively override this component's properties for this specific spawn.
    /// - Parameters:
    ///   - entityToSpawnOverride:  Overrides the `spawnTemplate` property for this call.
    ///   - parentOverride:         Specifies a different parent node for this call. Default: This component's entity's `NodeComponent` node.
    /// - Returns: `true` if the requested entity was successfully spawned by this component's entity's delegate (i.e. the scene).
    @discardableResult @inlinable
    open func spawn(
        _ entityToSpawnOverride:    OKEntity?   = nil,
        parentOverride:             SKNode?     = nil,
        positionOffsetOverride:     CGPoint?    = nil,
        angleOffsetOverride:        CGFloat?    = nil,
        distanceOffsetOverride:     CGFloat?    = nil,
        initialImpulseOverride:     CGFloat?    = nil,
        recoilImpulseOverride:      CGFloat?    = nil,
        actionOnSpawnOverride:      SKAction?   = nil)
        -> Bool
    {
        // MARK: Environment Verification
        // PERFORMANCE: Less expensive checks first.
        
        // This component must be part of an entity.
        guard let entity = self.entity else {
            OctopusKit.logForWarnings("\(self) is not part of an entity.")
            return false
        }
        
        // The spawner entity needs to have a visual representation (even if it's invisible) to spawn the new entity from.
        guard let spawnerNode = self.entityNode else {
            OctopusKit.logForWarnings("\(entity) has no SpriteKit node.")
            return false
        }
        
        // The spawner node needs to have a parent node.
        guard let spawnerNodeParent = spawnerNode.parent else {
            OctopusKit.logForWarnings("\(spawnerNode) has no parent.")
            return false
        }
        
        // The spawner entity needs to have an `OKEntityDelegate` (i.e. the parent scene) that will spawn the new entity for it.
        guard let spawnerDelegate = (entity as? OKEntity)?.delegate else {
            OctopusKit.logForWarnings("\(entity) has no OKEntityDelegate")
            return false
        }
        
        // We must have something to spawn.
        guard let entityToSpawn = entityToSpawnOverride ?? (spawnTemplate?.copy() as? OKEntity) else {
            OctopusKit.logForWarnings("No entityToSpawnOverride and spawnTemplate \(spawnTemplate) did not return .copy()")
            return false
        }
        
        // The spawned entity needs to have a visual representation (even if it's invisible).
        guard let nodeToSpawn = entityToSpawn.node else {
            OctopusKit.logForWarnings("\(entityToSpawn) has no SpriteKit node.")
            return false
        }
        
        // MARK: Setup
        
        // Replace default parameters with overrides, if any.
        
        let positionOffset      = positionOffsetOverride    ?? self.positionOffset
        let angleOffset         = angleOffsetOverride       ?? self.angleOffset
        let distanceOffset      = distanceOffsetOverride    ?? self.distanceOffset
        let initialImpulse      = initialImpulseOverride    ?? self.initialImpulse
        let recoilImpulse       = recoilImpulseOverride     ?? self.recoilImpulse
        let actionOnSpawn       = actionOnSpawnOverride     ?? self.actionOnSpawn
        
        // Set the position and direction.

        let parent              = parentOverride ?? spawnerNodeParent
        let spawnAngle          = spawnerNode.zRotation + angleOffset
        let spawnPosition       = (spawnerNode.position + positionOffset)
                                  .point(atAngle:  spawnAngle,
                                         distance: distanceOffset)
        
        // Convert the offset of the new spawn to the coordinate space of the spawner's parent node.
        nodeToSpawn.position    = parent.convert(spawnPosition, from: spawnerNodeParent)
        
        nodeToSpawn.zRotation   = spawnAngle
        
        // MARK: Spawn
        
        let didSpawnEntity      = spawnerDelegate.entity(entity, didSpawn: entityToSpawn)
        
        if  logSpawns {
            debugLog("spawner: \(spawnerNode), parent: \(parent), nodeToSpawn: \(nodeToSpawn), didSpawnEntity: \(didSpawnEntity)")
        }
        
        // MARK: Action
        
        if  let action = actionOnSpawn {
            nodeToSpawn.run(action)
        }
        
        // MARK: Impulse
        
        if  let initialImpulse = initialImpulse {
            
            guard let physicsBody = entityToSpawn.componentOrRelay(ofType: PhysicsComponent.self)?.physicsBody else {
                OctopusKit.logForWarnings("\(entityToSpawn) has no PhysicsComponent with a physicsBody — Cannot apply impulse.")
                return didSpawnEntity
            }
            
            let spawnAngle  = Float(spawnAngle)
            let impulse     = CGVector(dx: initialImpulse * CGFloat(cosf(spawnAngle)),
                                       dy: initialImpulse * CGFloat(sinf(spawnAngle)))
            
            physicsBody.applyImpulse(impulse)
        }
        
        // MARK: Recoil
        
        if  let recoilImpulse = recoilImpulse,
            didSpawnEntity
        {
            
            guard let spawnerPhysicsBody = coComponent(PhysicsComponent.self)?.physicsBody else {
                OctopusKit.logForWarnings("\(entity) has no PhysicsComponent with a physicsBody — Cannot apply recoil.")
                return didSpawnEntity
            }
            
            let spawnAngle = Float(spawnAngle)
            
            let recoil = CGVector(
                dx: (-recoilImpulse) * CGFloat(cosf(spawnAngle)),
                dy: (-recoilImpulse) * CGFloat(sinf(spawnAngle)))
            
            spawnerPhysicsBody.applyImpulse(recoil)
        }
        
        // MARK: Finish
        // Whew! Return a confirmation if we successfully spawned an entity. :)
        
        return didSpawnEntity
    }
}
