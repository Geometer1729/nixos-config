{-# LANGUAGE NamedFieldPuns #-}
-- Annoying for the layout type
{-# OPTIONS_GHC -Wno-missing-signatures #-}

module Config (main) where

import NamedScratchpad
import XMonad
import XMonad.Actions.GridSelect
import XMonad.Actions.Navigation2D
import XMonad.Actions.PhysicalScreens
import XMonad.Actions.WorkspaceNames
import XMonad.Hooks.DynamicLog
import XMonad.Hooks.EwmhDesktops (ewmh)
import XMonad.Hooks.ManageDocks
import XMonad.Hooks.ManageHelpers
import XMonad.Hooks.Minimize
import XMonad.Layout.Fullscreen
import XMonad.Layout.NoBorders
import XMonad.Layout.SubLayouts
import XMonad.Util.PureX
import XMonad.Util.Run

import Data.Functor
import Data.List (intercalate)
import Data.Ratio
import GHC.IO.Handle.Types
import Modes
import System.Exit

import Control.Monad (when)
import Control.Monad.Extra (unless)
import Data.Char (toLower)
import qualified Data.Map as M
import Data.Maybe (catMaybes)
import System.Environment (setEnv)
import System.Process.Extra (readProcess)
import XMonad.Actions.WorkspaceCursors (getFocus)
import XMonad.Hooks.RefocusLast (refocusLastLogHook)
import XMonad.Hooks.ServerMode (serverModeEventHook, serverModeEventHook', serverModeEventHookF)
import XMonad.Layout.Grid
import XMonad.Layout.Renamed (named)
import XMonad.StackSet (RationalRect)
import qualified XMonad.StackSet as W

main :: IO ()
main = do
  normalBorderColor <- liftIO $ init <$> runProcessWithInput "xrdb" ["-get", "color8"] ""
  focusedBorderColor <- liftIO $ init <$> runProcessWithInput "xrdb" ["-get", "color4"] ""
  yellow <- liftIO $ init <$> runProcessWithInput "xrdb" ["-get", "color3"] ""
  green <- liftIO $ init <$> runProcessWithInput "xrdb" ["-get", "color2"] ""
  -- colors based on these
  -- https://stylix.danth.me/styling.html?highlight=yellow#images
  -- https://github.com/danth/stylix/blob/master/modules/xresources/hm.nix
  h0 <- spawnPipe $ retry "xmobar -x 0"
  h1 <- spawnPipe $ retry "xmobar -x 1"
  let (modeStartHook, myKeys) = hookAndKeys
  xmonad $
    ewmh $
      docks $
        def
          { terminal = fst myTerminal
          , borderWidth = 1
          , normalBorderColor
          , focusedBorderColor
          , workspaces = myWorkspaces
          , keys = const myKeys
          , layoutHook = myLayout
          , manageHook = hooks <+> manageHook def <+> namedScratchpadManageHook spconf
          , handleEventHook =
              handleEventHook def
                <> modeHook
                <> serverModeEventHook'
                  ( pure
                      [
                        ( "scratchpad action sp"
                        , namedScratchpadAction spconf (Set False) "sp"
                        )
                      ]
                  )
          , startupHook = myStartupHook <> modeStartHook
          , focusFollowsMouse = False
          , logHook =
              myLogHook h0 yellow green
                <> myLogHook h1 yellow green
                <> (refocusLastLogHook >> nsHideOnFocusLoss spconf)
          , modMask = modm
          }

-- TODO this is kinda cringe but it works
retry :: String -> String
retry cmd = intercalate " || sleep 2s && " $ replicate 3 cmd

myTerminal :: (String, String)
myTerminal = ("alacritty", "Alacritty")

myStartupHook :: X ()
myStartupHook = do
  spawn "pgrep picom || picom"
  spawn "pgrep firefox || (sleep 10s ; firefox)"
  spawn "pgrep Discord || discord"
  spawn "echo \"connect 60:AB:D2:42:5E:19\" | bluetoothctl"

myLogHook :: Handle -> String -> String -> X ()
myLogHook pipe yellow green =
  workspaceNamesPP
    xmobarPP
      { ppOutput = hPutStrLn pipe
      , ppLayout = id -- const""
      , ppHidden = \w -> if w == "NSP" then "" else w
      , ppSep = " | "
      , ppCurrent = xmobarColor yellow "" . wrap "[" "]"
      , ppTitle = xmobarColor green "" . shorten 40
      }
    >>= dynamicLogWithPP

hooks :: ManageHook
hooks =
  manageDocks
    <> composeAll
      [ ( (title <&> (`elem` ("sp" : extraSps)))
            <&&> (className =? snd myTerminal)
        )
          <||> title
          =? "float"
          --> floatCenter
      , className =? "discord" --> doShift "21"
      , className =? ".blueman-manager-wrapped" --> floatCenter
      , className =? ".blueman-applet-wrapped" --> doKill
      , className =? "Steam" <&&> title =? "Steam" --> do
          doShift "10"
          doSink
      ]

doKill :: ManageHook
doKill = ask >>= liftX . killWindow >> return mempty

isPrefix :: String -> String -> Bool
isPrefix = fmap (fmap and) (zipWith (==))

myLayout =
  smartBorders $
    named "Def" (fullscreenFocus (avoidStruts Full))
      ||| named "Grid" (avoidStruts (GridRatio (8 / 9)))
      ||| fullscreenFocus Full

type Bindings = [((ButtonMask, KeySym), X ())]

modm, modShift, noMask :: KeyMask
modm = mod1Mask
modShift = modm .|. shiftMask
noMask = 0

hookAndKeys :: (X (), M.Map (ButtonMask, KeySym) (X ()))
hookAndKeys =
  usingModes
    [ ("Start", startMode)
    ]

-- TODO do I actually want any modes?

startMode :: Bindings
startMode =
  concat
    [ launchBindings
    , workSpaces
    , mediaKeys
    , scratchPads
    , layoutBindings
    ]

layoutBindings :: Bindings
layoutBindings =
  [ ((modm, xK_q), kill) -- close focused window
  , ((modShift, xK_q), liftIO exitSuccess) -- close xmonad
  , ((modm, xK_w), sendMessage (JumpToLayout "Def"))
  , ((modm, xK_g), sendMessage (JumpToLayout "Grid"))
  , ((modm, xK_f), sendMessage (JumpToLayout "Full"))
  , ((modShift, xK_w), sendMessage NextLayout)
  , ((modm, xK_Tab), windows W.focusUp)
  , ((modShift, xK_Tab), windows W.focusDown)
  , ((modm, xK_space), toggleFloat)
  , ((modm, xK_bracketleft), onPrevNeighbour def W.view)
  , ((modShift, xK_bracketleft), onPrevNeighbour def W.shift)
  , ((modm, xK_bracketright), onNextNeighbour def W.view)
  , ((modShift, xK_bracketright), onNextNeighbour def W.shift)
  , ((noMask, xK_Print), spawn "flameshot gui -c")
  , ((modShift, xK_b), spawn "echo 'connect 60:AB:D2:42:5E:19' | bluetoothctl")
  ]
    ++ [ ((mask, key), action dir False)
       | (mask, action) <- [(modm, windowGo), (modShift, windowSwap)]
       , (key, dir) <- [(xK_h, L), (xK_j, D), (xK_k, U), (xK_l, R)]
       ]

launchBindings :: Bindings
launchBindings =
  [ ((modm, xK_Return), spawn $ fst myTerminal)
  ,
    ( (modm, xK_d)
    , do
        screen <- curScreenId
        spawn $ "rofi -show run -monitor " <> show (toInteger screen - 1)
    )
  ,
    ( (modm, xK_s)
    , do
        screen <- curScreenId
        spawn $ "rofi -show ssh -monitor " <> show (toInteger screen - 1)
    )
  , ((modShift, xK_r), rebuild)
  , ((modShift, xK_s), spawn "sudo systemctl sleep")
  -- TODO systemctl sleep or so?
  ]

workSpaces :: Bindings
workSpaces =
  [ ((m .|. modm, k), windows $ f i)
  | (i, k) <- zip myWorkspaces ([xK_1 .. xK_9] ++ [xK_0] ++ [xK_F1 .. xK_F12])
  , (f, m) <- [(W.greedyView, 0), (W.shift, shiftMask)]
  ]

mediaKeys :: Bindings
mediaKeys =
  -- volume
  [ ((0, 0x1008ff13), volUp)
  , ((0, 0x1008ff11), volDown)
  , ((0, 0x1008ff12), toggleMute)
  , -- playerctl
    ((modm .|. shiftMask, xK_p), spawn "playPause")
  , ((0, 0x1008ff14), spawn "playPause")
  , ((modm, xK_o), spawn "playerctl next -a")
  , ((0, 0x1008ff17), spawn "playerctl next -a")
  ]
 where
  volUp = spawn "pulsemixer --change-volume +1"
  volDown = spawn "pulsemixer --change-volume -1"
  toggleMute = spawn "pulsemixer --toggle-mute"

scratchPads :: Bindings
scratchPads =
  [ ((modm, xK_n), toggle "sp")
  , ((modm, xK_m), toggle "ghci")
  , ((modm, xK_v), toggle "vim")
  , ((modm, xK_c), toggle "calcurse")
  , ((modm, xK_b), toggle "vit")
  ]
 where
  toggle = namedScratchpadAction spconf Toggle

toggleFloat :: X ()
toggleFloat =
  withFocused
    ( \windowId -> do
        floats <- gets (W.floating . windowset)
        if windowId `M.member` floats
          then withFocused $ windows . W.sink
          else windows $ W.float windowId center
    )

rebuild :: X ()
rebuild = withFocused $ \windowId -> do
  floats <- gets (W.floating . windowset)
  withDisplay $ \display ->
    withWindowAttributes display windowId $
      \attrs -> do
        -- TODO get from spconf
        isSp <- runQuery (className =? snd myTerminal <&&> title =? "sp") windowId
        namedScratchpadAction spconf (Set True) "sp"
        liftIO $ setEnv "HIDE_SP_AFTER_REBUILD" (toLower <$> show (not isSp))
        spawn "tmuxRebuild"

spconf :: [NamedScratchpad]
spconf = sp : (forApp <$> extraSps)

extraSps :: [String]
extraSps = ["vim", "ghci", "calcurse", "vit"]

sp :: NamedScratchpad
sp =
  NS
    "sp"
    (fst myTerminal ++ " -t sp -e tmux new-session -A -s sp")
    (className =? snd myTerminal <&&> title =? "sp")
    (doRectFloat $ W.RationalRect (1 % 4) (1 % 4) (1 % 2) (1 % 2))

forApp :: String -> NamedScratchpad
forApp s =
  NS
    s
    ( fst myTerminal
        <> " -t "
        <> s
        <> " -e "
        <> "tmux new-session -e "
        <> s
        <> " -A -s "
        <> s
        <> " "
        <> s
    )
    (className =? snd myTerminal <&&> title =? s)
    (doRectFloat $ W.RationalRect (1 % 4) (1 % 4) (1 % 2) (1 % 2))

myWorkspaces :: [String]
myWorkspaces = map show [1 .. 22 :: Int]

floatCenter :: ManageHook
floatCenter = doRectFloat center

center :: RationalRect
center = W.RationalRect (1 % 4) (1 % 4) (1 % 2) (1 % 2)
