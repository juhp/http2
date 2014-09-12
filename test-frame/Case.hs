{-# LANGUAGE OverloadedStrings, RecordWildCards #-}

module Case where

import Control.Applicative ((<$>))
import Data.ByteString (ByteString)
import Data.Hex
import Data.Maybe (fromJust)

import JSON
import Network.HTTP2

data CaseSource = CaseSource {
    cs_description :: String
  , cs_encodeinfo :: EncodeInfo
  , cs_payload :: FramePayload
  } deriving (Show,Read)

data CaseWire = CaseWire {
    wire_description :: String
  , wire_hex :: ByteString
  , wire_padding :: Maybe Pad
  , wire_error :: Maybe [ErrorCodeId]
  } deriving (Show,Read)

sourceToWire :: CaseSource -> CaseWire
sourceToWire CaseSource{..} = CaseWire {
    wire_description = cs_description
  , wire_hex = wire
  , wire_padding = Pad <$> encodePadding cs_encodeinfo
  , wire_error = Nothing
  }
  where
    frame = encodeFrame cs_encodeinfo cs_payload
    wire = hex frame

wireToCase :: CaseWire -> Case
wireToCase CaseWire { wire_error = Nothing, ..} = Case {
    draft = 14
  , description = wire_description
  , wire = wire_hex
  , frame = Just $ FramePad frm wire_padding
  , err = Nothing
  }
  where
    -- fromJust is unsafe
    frm = case decodeFrame defaultSettings $ fromJust $ unhex wire_hex of
        Left  e -> error $ show e
        Right r -> r
wireToCase CaseWire { wire_error = Just e, ..} = Case {
    draft = 14
  , description = wire_description
  , wire = wire_hex
  , frame = Nothing
  , err = Just $ fromErrorCodeId <$> e
  }
