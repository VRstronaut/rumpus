module Platform where
import Rumpus

roomCube = 4
(roomW, roomH, roomD) = (roomCube,roomCube,roomCube)
wallD = 1

roomOffset = -wallD/2

start :: Start
start = do

    spawnChild $ do
        myPose       ==> position (V3 0 roomOffset 0)
        myShape      ==> Cube
        myBody       ==> Animated
        myBodyFlags  ==> [Ungrabbable, Teleportable]
        mySize       ==> V3 roomW wallD roomD
        myColor      ==> colorHSL 0.25 0.8 0.2
    return ()
