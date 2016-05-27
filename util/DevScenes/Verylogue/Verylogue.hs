{-# LANGUAGE FlexibleContexts #-}
module DefaultStart where
import Rumpus

start :: Start
start = do
    removeChildren
    rootEntityID <- ask

    forM_ [0..12] $ \n -> spawnEntity $ pianokey rootEntityID n
    return Nothing

pianokey parentID n = do
    let note = n + 60
        x = fromIntegral n / 1.5 - 3
    myParent            ==> parentID
    myProperties ==> [Floating]
    myPose              ==> (identity & translation . _x .~ x)
    mySize              ==> 0.5
    myCollisionStart  ==> \_ _ -> do
        hue <- randomRange (0,1)
        myColor ==> colorHSL hue 0.8 0.4
        sendEntityPd parentID "piano-key" (List [fromIntegral note, 1])
    myCollisionEnd    ==> \_ -> do
        sendEntityPd parentID "piano-key" (List [fromIntegral note, 0])