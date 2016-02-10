{-# LANGUAGE TemplateHaskell #-}
{-# LANGUAGE FlexibleContexts #-}
module Rumpus.Systems.Animation where
import PreludeExtra
import Rumpus.ECS
import Rumpus.Types
import Rumpus.Systems.Physics
import Rumpus.Systems.Shared

defineComponentKeyWithType "ColorAnimation" [t|Animation (V4 GLfloat)|]
defineComponentKeyWithType "SizeAnimation" [t|Animation (V3 GLfloat)|]

tickAnimationSystem :: (MonadIO m, MonadState World m) => m ()
tickAnimationSystem = do
    now <- getNow
    forEntitiesWithComponent cmpColorAnimation $ \(entityID, animation) -> do
        let evaled = evalAnim now animation

        setComponent cmpColor (evanResult evaled) entityID
        when (evanRunning evaled == False) $ do
            removeComponentFromEntity cmpColorAnimation entityID

    forEntitiesWithComponent cmpSizeAnimation $ \(entityID, animation) -> do
        let evaled = evalAnim now animation

        setEntitySize (evanResult evaled) entityID
        when (evanRunning evaled == False) $ do
            removeComponentFromEntity cmpSizeAnimation entityID
