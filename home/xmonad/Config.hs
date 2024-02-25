{-# OPTIONS_GHC -Wno-missing-signatures #-} -- Annoying for the layout type
module Config (main) where

import XMonad
import XMonad.Actions.GridSelect
import XMonad.Actions.PhysicalScreens
import XMonad.Actions.WorkspaceNames
import XMonad.Hooks.DynamicLog
import XMonad.Hooks.EwmhDesktops(ewmh)
import XMonad.Hooks.ManageDocks
import XMonad.Hooks.ManageHelpers
import XMonad.Hooks.Minimize
import XMonad.Layout.NoBorders
import XMonad.Layout.SubLayouts
import NamedScratchpad
import XMonad.Util.Run
import XMonad.Util.PureX
import XMonad.Layout.Fullscreen
import XMonad.Actions.Navigation2D


import Modes
import Data.Ratio
import Data.List(intercalate)
import Data.Functor
import System.Exit
import GHC.IO.Handle.Types

import qualified XMonad.StackSet as W
import qualified Data.Map        as M
import XMonad.Hooks.RefocusLast (refocusLastLogHook)
import Control.Monad (when)
import Control.Monad.Extra (unless)
import XMonad.Hooks.ServerMode (serverModeEventHook', serverModeEventHook, serverModeEventHookF)
import System.Environment (setEnv)
import Data.Char (toLower)
import XMonad.Actions.WorkspaceCursors (getFocus)
import XMonad.Layout.Grid
import XMonad.Layout.Named (named)
import XMonad.StackSet (RationalRect)

main :: IO ()
main = do
    h0 <- spawnPipe $ retry "xmobar -x 0"
    h1 <- spawnPipe $ retry "xmobar -x 1"
    let (modeStartHook,myKeys) = hookAndKeys
    xmonad $ ewmh $ docks $
      def {
       terminal    = fst myTerminal
      ,borderWidth = 1
      ,normalBorderColor  = "#000044"
      ,focusedBorderColor = "#8080ff"
      ,workspaces = myWorkspaces
      ,keys = const myKeys
      ,layoutHook = myLayout
      ,manageHook = hooks <+> manageHook def <+> namedScratchpadManageHook spconf
      ,handleEventHook= handleEventHook def <> modeHook
        <> serverModeEventHook'
         (pure
           [ ("scratchpad action sp"
              ,namedScratchpadAction spconf (Set False) "sp")
           ]
         )
      ,startupHook = myStartupHook <> modeStartHook
      ,focusFollowsMouse = False
      ,logHook = myLogHook h0 <> myLogHook h1
        <> (refocusLastLogHook >> nsHideOnFocusLoss spconf)
      ,modMask = modm
    }

-- TODO this is kinda cringe but it works
retry :: String -> String
retry cmd = intercalate " || sleep 2s && " $ replicate 3 cmd

myTerminal :: (String,String)
myTerminal = ("alacritty","Alacritty")

myStartupHook :: X ()
myStartupHook = do
  spawn "pgrep picom || picom"
  spawn "pgrep firefox || firefox"
  spawn "pgrep Discord || discord"

myLogHook :: Handle -> X ()
myLogHook pipe = workspaceNamesPP xmobarPP {
   ppOutput = hPutStrLn pipe
  ,ppLayout= id -- const""
  ,ppHidden= \w->if w=="NSP"then""else w
  ,ppSep = " | "
  } >>= dynamicLogWithPP

hooks :: ManageHook
hooks = manageDocks <> composeAll
   [
   ((title <&> (`elem` ("sp":extraSps)))
    <&&> (className =? snd myTerminal))
    <||> title =? "float"
    --> floatCenter
   ,className =? "discord" --> doShift "21"
   ,className =? "Steam" <&&> title =? "Steam" --> do
      doShift "10"
      doSink
   ]

isPrefix :: String -> String -> Bool
isPrefix =  fmap (fmap and) (zipWith (==))

myLayout = smartBorders $
  named "Def" (fullscreenFocus  (avoidStruts Full))
  ||| named "Grid" (avoidStruts (GridRatio (8/9)))
  ||| fullscreenFocus  Full

type Bindings = [((ButtonMask,KeySym),X())]

modm,modShift,noMask :: KeyMask
modm     = mod1Mask
modShift = modm .|. shiftMask
noMask   = 0

hookAndKeys :: (X(),M.Map (ButtonMask,KeySym) (X ()))
hookAndKeys = usingModes
        [("Start" ,startMode )
        ]
-- TODO do I actually want any modes?

startMode :: Bindings
startMode = concat
    [ launchBindings
    , workSpaces
    , mediaKeys
    , scratchPads
    , layoutBindings
    ]

layoutBindings :: Bindings
layoutBindings =
    [ ((modm    , xK_q             ), kill) -- close focused window
    , ((modShift, xK_q             ), liftIO exitSuccess ) -- close xmonad
    , ((modm    , xK_w             ), sendMessage (JumpToLayout "Def"))
    , ((modShift, xK_w             ), sendMessage NextLayout)
    , ((modm    , xK_g             ), sendMessage (JumpToLayout "Grid"))
    , ((modm    , xK_f             ), sendMessage (JumpToLayout "Full"))
    , ((modm    , xK_Tab           ), windows W.focusUp)
    , ((modShift, xK_Tab           ), windows W.focusDown)
    , ((modm    , xK_space         ), toggleFloat)
    , ((modm    , xK_bracketleft   ), onPrevNeighbour def W.view)
    , ((modShift, xK_bracketleft   ), onPrevNeighbour def W.shift)
    , ((modm    , xK_bracketright  ), onNextNeighbour def W.view)
    , ((modShift, xK_bracketright  ), onNextNeighbour def W.shift)
    , ((noMask  , xK_Print         ), spawn "flameshot gui -c")
    ] ++
    [ ((mask,key),action dir False)
    | (mask,action) <- [(modm,windowGo),(modShift,windowSwap)]
    , (key,dir) <- [(xK_h,L),(xK_j,D),(xK_k,U),(xK_l,R)]
    ]

launchBindings :: Bindings
launchBindings =
    [ ((modm     , xK_Return ), spawn $ fst myTerminal )
    , ((modm     , xK_d      ),
      do
        screen <- curScreenId
        spawn $ "dmenu_run -i -m " <> show (toInteger screen)
      )
    , ((modShift , xK_r      ), rebuild)
    , ((modShift , xK_s      ), spawn "sudo zsh -c \"echo mem > /sys/power/state\"")
    -- TODO systemctl sleep or so?
    ]
-- TODO
-- dmenu all the machines with ssh config entries and
-- launch a terminal sshing into one
-- without (local) tmux

workSpaces :: Bindings
workSpaces =
    [((m .|. modm, k), windows $ f i)
       | (i, k) <- zip myWorkspaces ([xK_1..xK_9] ++ [xK_0] ++ [xK_F1..xK_F12])
       , (f, m) <- [(W.greedyView,0) , (W.shift,shiftMask)]]

mediaKeys :: Bindings
mediaKeys =
    -- volume
    [ ((0,0x1008ff13), spawn "pulsemixer --change-volume +1" )
    , ((0,0x1008ff11), spawn "pulsemixer --change-volume -1" )
    , ((0,0x1008ff12), toggleMute )
    --playerctl
    , ((modm .|. shiftMask, xK_p), spawn "playPause")
    , ((modm,xK_o), spawn "playerctl next -a")
    ]

scratchPads :: Bindings
scratchPads =
    [ ((modm,xK_n),namedScratchpadAction spconf Toggle "sp" )
    , ((modm,xK_m),namedScratchpadAction spconf Toggle "ghci" )
    , ((modm,xK_v),namedScratchpadAction spconf Toggle "vim" )
    , ((modm,xK_c),namedScratchpadAction spconf Toggle "calcurse")
    ]

toggleMute :: X()
toggleMute = spawn "pulsemixer --toggle-mute"

toggleFloat :: X ()
toggleFloat = withFocused
  (\windowId -> do
      floats <- gets (W.floating . windowset)
      if windowId `M.member` floats
        then withFocused $ windows . W.sink
        else windows $ W.float windowId center
  )

rebuild :: X ()
rebuild = withFocused $ \windowId -> do
  floats <- gets (W.floating . windowset)
  withDisplay $ \display ->
    withWindowAttributes display windowId
      $ \attrs -> do
        -- TODO get from spconf
        isSp <- runQuery (className =? snd myTerminal <&&> title =? "sp") windowId
        namedScratchpadAction spconf (Set True) "sp"
        liftIO $ setEnv "HIDE_SP_AFTER_REBUILD" (toLower <$> show (not isSp))
        spawn "tmuxRebuild"

spconf :: [NamedScratchpad]
spconf = sp: (forApp <$> extraSps)

extraSps :: [String]
extraSps = ["vim","ghci","calcurse"]

sp :: NamedScratchpad
sp = NS "sp"
  (fst myTerminal ++ " -t sp -e tmux new-session -A -s sp")
  (className =? snd myTerminal <&&> title =? "sp")
  (doRectFloat $ W.RationalRect (1%4) (1%4) (1%2) (1%2))


forApp :: String -> NamedScratchpad
forApp s = NS s
  (fst myTerminal <> " -t " <> s <> " -e "
    <> "tmux new-session -e " <> s <> " -A -s " <> s <> " " <> s)
  (className =? snd myTerminal <&&> title =? s)
  (doRectFloat $ W.RationalRect (1%4) (1%4) (1%2) (1%2))

myWorkspaces :: [String]
myWorkspaces = map show [1..22 :: Int]

floatCenter :: ManageHook
floatCenter = doRectFloat center

center :: RationalRect
center = W.RationalRect (1%4) (1%4) (1%2) (1%2)
