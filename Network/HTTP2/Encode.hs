{-# LANGUAGE RecordWildCards #-}

module Network.HTTP2.Encode (
    encodeFrame
  , encodeFrameHeader
  , encodeFramePayload
  , buildFrame
  , buildFrameHeader
  , buildFramePayload
  ) where

import Blaze.ByteString.Builder (Builder)
import qualified Blaze.ByteString.Builder as BB
import Data.Bits
import Data.ByteString (ByteString)
import qualified Data.ByteString.Lazy as BL
import Data.Monoid ((<>))

import Network.HTTP2.Types

----------------------------------------------------------------

encodeFrame :: FramePayload -> FrameFlags -> Maybe Padding -> ByteString
encodeFrame payload flags mpadding = run $ buildFrame payload flags mpadding

encodeFrameHeader :: FrameTypeId -> FrameHeader -> ByteString
encodeFrameHeader fid header = run $ buildFrameHeader fid header

encodeFramePayload :: FramePayload -> FrameFlags -> Maybe Padding -> ByteString
encodeFramePayload payload flags mpadding = run payloadBuilder
  where
    (_, _, payloadBuilder) = buildFramePayload payload flags mpadding

run :: Builder -> ByteString
run = BL.toStrict . BB.toLazyByteString

----------------------------------------------------------------

buildFrame :: FramePayload -> FrameFlags -> Maybe Padding -> Builder
buildFrame payload flags mpadding = headerBuilder <> payloadBuilder
  where
    (fid, header, payloadBuilder) = buildFramePayload payload flags mpadding
    headerBuilder = buildFrameHeader fid header

----------------------------------------------------------------

buildFrameHeader :: FrameTypeId -> FrameHeader -> Builder
buildFrameHeader fid FrameHeader{..} = len <> typ <> flg <> sid
  where
    -- fixme: 2^14 check
    len1 = BB.fromWord16be (fromIntegral (payloadLength `shiftR` 8))
    len2 = BB.fromWord8 (fromIntegral (payloadLength .&. 0xff))
    len = len1 <> len2
    typ = BB.fromWord8 fid
    flg = BB.fromWord8 flags
    sid = BB.fromWord32be $ fromStreamIdentifier streamId

----------------------------------------------------------------

buildFramePayload :: FramePayload -> FrameFlags -> Maybe Padding
                  -> (FrameTypeId, FrameHeader, Builder)
buildFramePayload payload _ _ = (undefined, undefined, buildPayload payload)

buildPayload :: FramePayload -> Builder

-- fixme: padding
buildPayload (DataFrame body) = BB.fromByteString body

-- fixme: padding
buildPayload (HeaderFrame (Just p) hdr) = buildPriority p <> BB.fromByteString hdr
buildPayload (HeaderFrame Nothing hdr) = BB.fromByteString hdr

buildPayload (PriorityFrame p) = buildPriority p

buildPayload (RSTStreamFrame e) = buildErrorCode e

buildPayload (SettingsFrame _) = undefined
buildPayload (PushPromiseFrame _ _) = undefined

buildPayload (PingFrame bs) = BB.fromByteString bs

buildPayload (GoAwayFrame sid e bs) =
    buildStreamIdentifier sid <> buildErrorCode e <> BB.fromByteString bs

buildPayload (WindowUpdateFrame _) = undefined

buildPayload (ContinuationFrame hdr) = BB.fromByteString hdr
buildPayload (UnknownFrame _ _) = undefined

buildPriority :: Priority -> Builder
buildPriority = undefined

buildErrorCode :: ErrorCode -> Builder
buildErrorCode = undefined

buildStreamIdentifier :: StreamIdentifier -> Builder
buildStreamIdentifier = undefined