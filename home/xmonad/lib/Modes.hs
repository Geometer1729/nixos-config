module Modes
(usingModes
,modeSwitch
,modeHook
,Mode (Mode)
)
where

import Data.Function
import Data.Tuple.Extra
import Data.List
import Control.Monad
import Data.Monoid

import XMonad
--import XMonad.Util.Paste
import qualified XMonad.Util.ExtensibleState as ES

import qualified Data.Map as M

usingModes :: [(String,[((ButtonMask,KeySym),X ())])] -> (X (),M.Map (ButtonMask,KeySym) (X ()))
usingModes modes = (hook,M.map withMode byKey)
    where
      trios :: [((ButtonMask,KeySym),Mode,X ())]
      trios = sortOn (\(key,mode,_) -> (key,mode)) [ (key,Mode mode,action) | (mode,keyMap) <- modes , (key,action) <- keyMap ]
      byKey :: M.Map (ButtonMask,KeySym) (M.Map Mode (X ()))
      byKey = M.fromList [ (fst3 (head forKey), M.fromList (map (\(_,mode,action) -> (mode,action)) forKey))
                  | forKey <- groupBy ((==) `on` fst3) trios ]
      withMode :: M.Map Mode (X ()) -> X ()
      withMode  modeMap = do
        mode <- ES.get
        case M.lookup mode modeMap of
            Nothing     -> return ()
            Just action -> action
      hook :: X ()
      hook = do
        ES.put $ ModeList $ M.fromList [(Mode w,map fst binds) | (w,binds) <- modes ]
        grabKeys

modeSwitch :: String -> X ()
modeSwitch w = do
    ES.put (Mode w)
    grabKeys

grabKeys :: X ()
grabKeys = do
  mode <- ES.get :: X Mode
  ModeList modeList <- ES.get
  let maybeKeys = M.lookup mode modeList
  case maybeKeys of
      -- this case should only come up if you switch to a mode with no keybinds
      -- ideally modeSwitch shouldn't allow this
      Nothing -> return ()
      Just boundKeys -> do
          -- This block is a modification of grabKeys from Main.hs in xmonad
          -- it instead grabs onl the keys bound in the current mode
          XConf{display = dpy,theRoot = rootw} <- ask
          let grab kc m = io $ grabKey dpy kc m rootw True grabModeAsync grabModeAsync
          let (minCode, maxCode) = displayKeycodes dpy
          let allCodes = [fromIntegral minCode .. fromIntegral maxCode]
          io $ ungrabKey dpy anyKey anyModifier rootw
          syms <- forM allCodes $ \code -> io (keycodeToKeysym dpy code 0)
          let keysymMap = M.fromListWith (++) (zip syms [[code] | code <- allCodes])
              keysymToKeycodes sym = M.findWithDefault [] sym keysymMap
          forM_ boundKeys $ \(mask,sym) ->
               forM_ (keysymToKeycodes sym) $ \kc ->
                    mapM_ (grab kc . (mask .|.)) =<< extraModifiers

-- modification of the handleing in XMonad main to use the local grabKeys
modeHook :: Event -> X All
modeHook e@MappingNotifyEvent{} = do
    io $ refreshKeyboardMapping e
    when (ev_request e `elem` [mappingKeyboard, mappingModifier]) $ do
        grabKeys
    return (All False)
modeHook _ = return (All True)


newtype Mode = Mode String deriving(Read,Show,Eq,Ord)

instance ExtensionClass Mode where
  initialValue = Mode "Start"

newtype ModeList = ModeList (M.Map Mode [(KeyMask,KeySym)]) deriving (Read,Show,Eq,Ord)

instance ExtensionClass ModeList where
  initialValue = ModeList M.empty

