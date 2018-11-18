{-# LANGUAGE OverloadedStrings #-}

module NotifyChanges
(
    waitForChange
)
where

import Core.Program
import Core.System
import Control.Concurrent.MVar (MVar, newEmptyMVar, putMVar, readMVar)
import qualified Data.ByteString.Char8 as C (ByteString, pack, unpack)
import Data.Foldable (foldr, foldrM)
import Data.HashSet (HashSet)
import qualified Data.HashSet as HashSet (empty, insert, member)
import System.FilePath.Posix (dropFileName)
import System.INotify (EventVariety(..), Event(..), withINotify
    , addWatch, removeWatch)

import Environment

{-
Ideally we'd just set up inotifies on individual files we have manifested
from the .book file, but that doesn't work when programs like vim move the
original file, save a new one, then delete the renamed original. From
previous work we know that CLOSE_WRITE is emitted reliably through these
sequences, so we can just check to see if a that happens on a filename we
care about (rather then the original inodes those files were stored in).

Insert a 100ms pause before rebuilding to allow whatever the editor
was to finish its write and switcheroo sequence.
-}
waitForChange :: [FilePath] -> Program t ()
waitForChange files =
  let
    f :: FilePath -> HashSet C.ByteString -> HashSet C.ByteString
    f path acc = HashSet.insert (C.pack path) acc

    g :: FilePath -> HashSet C.ByteString -> HashSet C.ByteString
    g path acc = HashSet.insert (C.pack (dropFileName path)) acc
  in do
    event "Watching for changes"

    let paths = foldr f HashSet.empty files
    let dirs  = foldr g HashSet.empty files

    withContext $ \runProgram -> do
        block <- newEmptyMVar
        withINotify $ \notify -> do
            -- setup inotifies
            watches <- foldrM (\dir acc -> do
                runProgram (debugS "watching" dir)
                watch <- addWatch notify [CloseWrite] dir (\event ->
                    case event of
                        Closed _ (Just file) _  -> do
                            let path = if dir == "./"
                                        then file
                                        else dir <> file
                            runProgram (debugS "changed" path)
                            if HashSet.member path paths
                                then do
                                    runProgram (debugS "trigger" path)
                                    putMVar block False
                                else
                                    return ()
                        _ -> return ())
                return (watch:acc)) [] dirs

            -- wait
            readMVar block
            -- cleanup
            mapM_ removeWatch watches

    sleep 0.1

