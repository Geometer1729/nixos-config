{-# OPTIONS_GHC -Wno-missing-signatures #-} -- Annoying for the layout type
module Config (main) where

--import XMonad.Actions.Commands
--import XMonad.Actions.FloatKeys
--import XMonad.Actions.Search
--import XMonad.Actions.WindowBringer
--import XMonad.Actions.WindowGo
--import XMonad.Config.Prime (runQuery)
--import XMonad.Hooks.PositionStoreHooks
--import XMonad.Layout.Decoration
--import XMonad.Layout.IndependentScreens
--import XMonad.Layout.LayoutModifier
--import XMonad.Layout.MultiToggle
--import XMonad.Layout.SimpleDecoration
--import XMonad.Layout.ThreeColumns
--import XMonad.Prompt.Window
--import XMonad.Util.Dmenu
--import XMonad.Util.Dzen
--import XMonad.Util.NamedWindows (getName)
--import XMonad.Layout.Gaps
import XMonad
import XMonad.Actions.GridSelect
import XMonad.Actions.Navigation2D
import XMonad.Actions.PhysicalScreens
import XMonad.Actions.WorkspaceNames
import XMonad.Hooks.DynamicLog
import XMonad.Hooks.EwmhDesktops(ewmh)
import XMonad.Hooks.ManageDocks
import XMonad.Hooks.ManageHelpers
import XMonad.Hooks.Minimize
import XMonad.Layout.BinarySpacePartition
import XMonad.Layout.NoBorders
import XMonad.Layout.SubLayouts
import XMonad.Util.NamedScratchpad
import XMonad.Util.Run
import XMonad.Util.PureX
import XMonad.Layout.Fullscreen


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
           [ ("scratchpad action sp" , namedScratchpadAction spconf "sp")
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
  spawn "pgrep firefox || firefox"
  spawn "pgrep Discord || discord"
  -- spawn "~/scripts/startup"
  --viewScreen def (P 0)
  --windows (W.greedyView "1")
  --viewScreen def (P 1)
  --windows (W.greedyView "2")

myLogHook :: Handle -> X ()
myLogHook pipe = workspaceNamesPP xmobarPP {
   ppOutput = hPutStrLn pipe
  ,ppLayout=const""
  ,ppHidden= \w->if w=="NSP"then""else w
  ,ppSep = " | "
  } >>= dynamicLogWithPP

hooks :: ManageHook
hooks = manageDocks <> composeAll
   [
   (title <&> (`elem` ("sp":extraSps)))
   <&&> (className =? snd myTerminal)
   --> doRectFloat (W.RationalRect (1%4) (1%4) (1%2) (1%2))
   ,className =? "discord" --> doShift "21"
   --,className =? "Steam" <&&> (title <&> isPrefix "Steam - News")
   --       --> doCenterFloat
   ,className =? "Steam" <&&> title =? "Steam" --> do
      doShift "10"
      doSink
   ,title =? "float" -->
      doRectFloat (W.RationalRect (1%4) (1%4) (1%2) (1%2))
      -- TODO factor out as floatCenter or something
   ]

isPrefix :: String -> String -> Bool
isPrefix =  fmap (fmap and) (zipWith (==))

myLayout = smartBorders $
  avoidStruts emptyBSP
  ||| fullscreenFocus  (avoidStruts Full)
  ||| fullscreenFocus  Full

type Bindings = [((ButtonMask,KeySym),X())]

modm,modShift,noMask :: KeyMask
modm     = mod1Mask
modShift = modm .|. shiftMask
noMask   = 0

hookAndKeys :: (X(),M.Map (ButtonMask,KeySym) (X ()))
hookAndKeys = usingModes
        [("Start" ,startMode )
        ,("resize",resize )
        ]

startMode :: Bindings
startMode = concat
    [ launchBindings
    , workSpaces
    , mediaKeys
    , scratchPads
    , layoutBindings
    ] ++ [((modm , xK_r),modeSwitch "resize")]

layoutBindings :: Bindings
layoutBindings =
    [ ((modm    , xK_q             ), kill) -- close focused window
    , ((modShift, xK_q             ), liftIO exitSuccess ) -- close xmonad
    , ((modm    , xK_w             ), sendMessage NextLayout)
    , ((modShift, xK_w             ), sendMessage FirstLayout)
    , ((modm    , xK_h             ), sendMessage Shrink)
    , ((modm    , xK_y             ), sendMessage FocusParent)
    , ((modm    , xK_u             ), sendMessage Rotate)
    , ((modm    , xK_i             ), sendMessage Swap)
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

resize :: Bindings
resize =
    ((noMask , xK_Escape ), modeSwitch "Start"):
    [ ((mask,key),sendMessage $ action dir)
    | (mask,action) <- [(noMask,ExpandTowards),(shiftMask,ShrinkFrom)]
    , (key ,dir   ) <- [(xK_h,L),(xK_j,D),(xK_k,U),(xK_l,R)]
    ]

launchBindings :: Bindings
launchBindings =
    [ ((modm     , xK_Return ), spawn $ fst myTerminal ) -- launch a terminal
    , ((modm     , xK_d      ),
      do
        screen <- curScreenId
        spawn $ "dmenu_run -i -m " <> show (toInteger screen)
      )
    , ((modShift , xK_r      ), rebuild)
    , ((modShift , xK_s      ), spawn "sudo zsh -c \"echo mem > /sys/power/state\"")
    -- TODO systemctl sleep or so?
    ]

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
    [ ((modm,xK_n),namedScratchpadAction spconf "sp")
    , ((modm,xK_m),namedScratchpadAction spconf "ghci")
    , ((modm,xK_v),namedScratchpadAction spconf "vim")
    , ((modm,xK_c),namedScratchpadAction spconf "calcurse")
    ]

toggleMute :: X()
toggleMute = spawn "pulsemixer --toggle-mute"

toggleFloat :: X ()
toggleFloat = withFocused
  (\windowId -> do
      floats <- gets (W.floating . windowset)
      if windowId `M.member` floats
        then withFocused $ windows . W.sink
        else windows $ W.float windowId
          (W.RationalRect (1 % 4) (1 % 4) (1 % 2) (1 % 2))
  )

-- TODO It's probably best to just fork the scratchpad library
-- and add non-toggle focus and hide actions
rebuild :: X ()
rebuild = withFocused $ \windowId -> do
  floats <- gets (W.floating . windowset)
  withDisplay $ \display ->
    withWindowAttributes display windowId
      $ \attrs -> do
        -- TODO get from spconf
        isSp <- runQuery (className =? snd myTerminal <&&> title =? "sp") windowId
        unless isSp $ namedScratchpadAction spconf "sp"
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
