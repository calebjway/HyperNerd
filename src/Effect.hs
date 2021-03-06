{-# LANGUAGE InstanceSigs #-}
{-# LANGUAGE FlexibleInstances #-}
module Effect ( Effect
              , EffectF (..)
              , say
              , logMsg
              , createEntity
              , getEntityById
              , getRandomEntity
              , httpRequest
              , now
              , timeout
              , errorEff
              , twitchApiRequest
              ) where

import           Control.Monad.Catch
import           Control.Monad.Free
import qualified Data.ByteString.Lazy.Char8 as B8
import qualified Data.Text as T
import           Data.Time
import           Entity
import           Network.HTTP.Simple

data EffectF s = Say T.Text s
               | LogMsg T.Text s
               | ErrorEff T.Text
               | CreateEntity T.Text Properties (Entity -> s)
               | GetEntityById T.Text Int (Maybe Entity -> s)
               | GetRandomEntity T.Text (Maybe Entity -> s)
               | Now (UTCTime -> s)
               | HttpRequest Request (Response B8.ByteString -> s)
               | TwitchApiRequest Request (Response B8.ByteString -> s)
               | Timeout Integer (Effect ()) s

instance Functor EffectF where
    fmap f (Say msg s) = Say msg (f s)
    fmap f (LogMsg msg s) = LogMsg msg (f s)
    fmap f (CreateEntity name properties h) =
        CreateEntity name properties (f . h)
    fmap _ (ErrorEff text) = ErrorEff text
    fmap f (GetEntityById name ident h) =
        GetEntityById name ident (f . h)
    fmap f (GetRandomEntity name h) =
        GetRandomEntity name (f . h)
    fmap f (Now h) = Now (f . h)
    fmap f (HttpRequest r h) = HttpRequest r (f . h)
    fmap f (TwitchApiRequest r h) = TwitchApiRequest r (f . h)
    fmap f (Timeout t e h) = Timeout t e (f h)

type Effect = Free EffectF

instance MonadThrow Effect where
    throwM :: Exception e => e -> Effect a
    throwM = errorEff . T.pack . displayException

say :: T.Text -> Effect ()
say msg = liftF $ Say msg ()

logMsg :: T.Text -> Effect ()
logMsg msg = liftF $ LogMsg msg ()

createEntity :: T.Text -> Properties -> Effect Entity
createEntity name properties = liftF $ CreateEntity name properties id

getEntityById :: T.Text -> Int -> Effect (Maybe Entity)
getEntityById name ident = liftF $ GetEntityById name ident id

getRandomEntity :: T.Text -> Effect (Maybe Entity)
getRandomEntity name = liftF $ GetRandomEntity name id

now :: Effect UTCTime
now = liftF $ Now id

httpRequest :: Request -> Effect (Response B8.ByteString)
httpRequest request = liftF $ HttpRequest request id

twitchApiRequest :: Request -> Effect (Response B8.ByteString)
twitchApiRequest request = liftF $ TwitchApiRequest request id

timeout :: Integer -> Effect () -> Effect ()
timeout t e = liftF $ Timeout t e ()

errorEff :: T.Text -> Effect a
errorEff t = liftF $ ErrorEff t
