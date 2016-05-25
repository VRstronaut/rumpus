{-# LANGUAGE OverloadedStrings #-}

module Rumpus.Main where
import Rumpus
import Rumpus.TestScene

rumpusMain :: IO ()
rumpusMain = withRumpusGHC $ \ghc -> withPd $ \pd -> do
    vrPal <- initVRPal "Rumpus" [UseOpenVR]

    void . flip runStateT newECS $ do

        initAnimationSystem
        initAttachmentSystem
        initClockSystem
        initCodeEditorSystem ghc
        initCollisionsSystem
        initConstraintSystem
        initControlsSystem vrPal
        initCreatorSystem
        initDragSystem
        initHapticsSystem
        initLifetimeSystem
        initPhysicsSystem
        initPlayPauseSystem
        initProfilerSystem
        initRenderSystem
        initSoundSystem pd
        initSelectionSystem
        initSceneSystem
        initSceneLoaderSystem
        initSceneWatcherSystem
        initSharedSystem
        initTextSystem

        startHandsSystem
        startKeyPadsSystem
        startSceneLoaderSystem
        startSceneWatcherSystem
        when isBeingProfiled loadTestScene

        singleThreadedLoop vrPal
        --multithreadedLoop1 vrPal
        --multithreadedLoop2 vrPal

singleThreadedLoop :: VRPal -> ECSMonad ()
singleThreadedLoop vrPal = do
    whileWindow (gpWindow vrPal) $ do
        playerM44 <- viewSystem sysControls ctsPlayer
        (headM44, events) <- tickVR vrPal playerM44
        profile "Controls" $ tickControlEventsSystem headM44 events
        profile "Rendering" $ tickRenderSystem headM44

        -- Perform a minor GC to just get the young objects created during the last frame
        -- without traversing all of memory
        --liftIO performMinorGC

        profile "KeyPads" $ tickKeyPadsSystem
        profile "Clock" $ tickClockSystem
        profile "CodeEditorInput" $ tickCodeEditorInputSystem
        profile "CodeEditorResults" $ tickCodeEditorResultsSystem
        profile "Attachment" $ tickAttachmentSystem
        profile "Constraint" $ tickConstraintSystem
        profile "Script" $ tickScriptSystem
        profile "Lifetime" $ tickLifetimeSystem
        profile "Animation" $ tickAnimationSystem
        profile "Physics" $ tickPhysicsSystem
        profile "SyncPhysicsPoses" $ tickSyncPhysicsPosesSystem
        profile "Collisions" $ tickCollisionsSystem
        profile "HandControls" $ tickHandControlsSystem
        profile "Sound" $ tickSoundSystem
        profile "SceneWatcher" $ tickSceneWatcherSystem


-- Experiment with placing drawing on the background thread. Doesn't render to window.
multithreadedLoop1 vrPal = do
        renderChan <- liftIO newChan
        renderWorker <- liftIO . forkOS $ do
            makeContextCurrent (Just (gpThreadWindow vrPal))
            void . forever $ do
                join (readChan renderChan)
        let onRenderThread action = do
                ecs <- get
                liftIO $ writeChan renderChan (runStateT action ecs)

        whileWindow (gpWindow vrPal) $ do
            playerM44 <- viewSystem sysControls ctsPlayer
            (headM44, events) <- tickVR vrPal playerM44
            profile "Controls" $ tickControlEventsSystem headM44 events
            profile "Rendering" $ onRenderThread $ tickRenderSystem headM44
            --profile "Rendering" $ tickRenderSystem headM44

            -- Perform a minor GC to just get the young objects created during the last frame
            -- without traversing all of memory
            --liftIO performMinorGC

            profile "KeyPads" $ tickKeyPadsSystem
            profile "Clock" $ tickClockSystem
            profile "CodeEditorInput" $ tickCodeEditorInputSystem
            profile "CodeEditorResults" $ tickCodeEditorResultsSystem
            profile "Attachment" $ tickAttachmentSystem
            profile "Constraint" $ tickConstraintSystem
            profile "Script" $ tickScriptSystem
            profile "Lifetime" $ tickLifetimeSystem
            profile "Animation" $ tickAnimationSystem
            profile "Physics" $ tickPhysicsSystem
            profile "SyncPhysicsPoses" $ tickSyncPhysicsPosesSystem
            profile "Collisions" $ tickCollisionsSystem
            profile "HandControls" $ tickHandControlsSystem
            profile "Sound" $ tickSoundSystem
            profile "SceneWatcher" $ tickSceneWatcherSystem

-- Experiment with running logic on the background thread.
-- Attempts to never stall the render thread,
-- (i.e. it will reuse the last world state and render it from the latest head position)
-- and has logic thread wait until a new device pose has arrived
-- from OpenVR before ticking.
multiThreadedLoop2 vrPal = do
        startingECS <- get
        backgroundBox <- liftIO $ newTVarIO Nothing
        mainThreadBox <- liftIO $ newTVarIO startingECS
        liftIO . forkOS $ do
            makeContextCurrent (Just (gpThreadWindow vrPal))
            void . flip runStateT startingECS . forever $ do
                (headM44, events) <- atomically $ do
                    readTVar backgroundBox >>= \case
                        Just something -> do
                            writeTVar backgroundBox Nothing
                            return something
                        Nothing -> retry

                profile "Controls" $ tickControlEventsSystem headM44 events
                profile "KeyPads" $ tickKeyPadsSystem
                profile "Clock" $ tickClockSystem
                profile "CodeEditorInput" $ tickCodeEditorInputSystem
                profile "CodeEditorResults" $ tickCodeEditorResultsSystem
                profile "Attachment" $ tickAttachmentSystem
                profile "Constraint" $ tickConstraintSystem
                profile "Script" $ tickScriptSystem
                profile "Lifetime" $ tickLifetimeSystem
                profile "Animation" $ tickAnimationSystem
                profile "Physics" $ tickPhysicsSystem
                profile "SyncPhysicsPoses" $ tickSyncPhysicsPosesSystem
                profile "Collisions" $ tickCollisionsSystem
                profile "HandControls" $ tickHandControlsSystem
                profile "Sound" $ tickSoundSystem
                profile "SceneWatcher" $ tickSceneWatcherSystem

                newECS <- get
                atomically $ do
                    writeTVar mainThreadBox newECS


        whileWindow (gpWindow vrPal) $ do
            ecs <- profileMS "rd" 0 $ liftIO . atomically $ readTVar mainThreadBox
            (headM44, events) <- profileMS "render" 0 $ flip evalStateT ecs (do
                playerM44 <- viewSystem sysControls ctsPlayer
                (headM44, events) <- profileMS "tick" 1 $ tickVR vrPal playerM44
                profileMS "draw" 1 $ tickRenderSystem headM44
                return (headM44, events))
            profileMS "wr" 0 $ liftIO . atomically $ do
                pendingEvents <- readTVar backgroundBox >>= \case
                    Just (_, pendingEvents) -> return pendingEvents
                    Nothing -> return []
                writeTVar backgroundBox (Just (headM44, pendingEvents ++ events))

