module Room where
import Rumpus

roomCube = 4
(roomW, roomH, roomD) = (roomCube,roomCube,roomCube)
wallD = 1
shelfH = 0.15

roomOffset = (roomH/2 - wallD/2)

start :: OnStart
start = do
    setPose (identity & translation .~ V3 0 roomOffset (-roomD/2 + 0.4))
    removeChildren
    builderID <- ask
    let makeWall pos size hue extraProps = spawnEntity Transient $ do
            myParent            ==> builderID
            myPose              ==> mkTransformation 
                (axisAngle (V3 0 0 1) 0) (pos & _y +~ roomOffset)
            myShapeType         ==> CubeShape
            myPhysicsProperties ==> extraProps ++ [Kinematic, Static]
            mySize              ==> size
            myColor             ==> hslColor hue 0.8 0.6
            myMass              ==> 0
    --makeWall (V3 0 0 (-roomD/2)) (V3 roomW roomH wallD) 0.1 [] -- back
    makeWall (V3 0 0 (roomD/2))  (V3 (roomW*0.99) roomH wallD) 0.2 [] -- front
    --makeWall (V3 (-roomW/2) 0 0) (V3 wallD roomH roomD) 0.3 [] -- left
    --makeWall (V3 (roomW/2)  0 0) (V3 wallD roomH roomD) 0.4 [] -- right
    makeWall (V3 0 (-roomH/2) 0) (V3 roomW wallD roomD) 0.5 [Teleportable] -- floor
    makeWall (V3 (-10) (-roomH/2) 0) (V3 roomW wallD roomD) 0.5 [Teleportable] -- floor2
    makeWall (V3 (10) (-roomH/2) 0) (V3 roomW wallD roomD) 0.5 [Teleportable] -- floor2
    makeWall (V3 0 (-roomH/2) (-10)) (V3 roomW wallD roomD) 0.5 [Teleportable] -- floor2
    makeWall (V3 0 (-roomH/2) (10)) (V3 roomW wallD roomD) 0.5 [Teleportable] -- floor2

    makeWall (V3 0 (-roomH/2 + 10) (-20)) (V3 roomW wallD roomD) 0.5 [Teleportable] -- floor2

    makeWall (V3 0 (roomH/2)  0) (V3 roomW wallD roomD) 0.6 [] -- ceiling
    
    let numShelves = 4
    forM_ [1..(numShelves - 1)] $ \n -> do
        let shelfY = (roomH/realToFrac numShelves) 
                        * fromIntegral n - (roomH/2)
        makeWall (V3 0 shelfY (roomD/2)) 
                 (V3 roomW shelfH (wallD*2)) 0.7 [] -- shelf

    return Nothing