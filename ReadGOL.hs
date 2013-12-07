module ReadGOL where

import World
import Parsing
import Data.Char
import Data.Maybe

-----------------------------------------------------------------------------
{- Adapted from ReadExprMonadic -}
-- Natural number parser
nat :: Parser Int
nat = do ds <- oneOrMore digit
         return (read ds)

-- Integer parser
integer :: Parser Int 
integer = nat +++ neg -- natural or negative
  where neg = do char '-'
                 n <- nat
                 return $ negate n
-----------------------------------------------------------------------------


specString :: String -> Parser String
specString []     = failure
specString [c]    = pmap (:[]) (char c)
specString (c:cs) = char c <:> specString cs

offset :: Parser Pair
offset = specString "#P" >-> oneOrMore (sat isSpace) >->
         (integer >*> (\y -> oneOrMore (sat isSpace) >->
                             integer >*> \x -> success (x,y))) <-< char '\n'

offset' :: Parser Pair
offset' = specString "#P" >-> oneOrMore (sat isSpace) >->
          do
            y <- integer
            x <- oneOrMore (sat isSpace) >-> integer <-< char '\n'
            return (x,y)

offset'' :: Parser Pair
offset'' = do
             specString "#P"
             oneOrMore (sat isSpace)
             y <- integer
             oneOrMore (sat isSpace)
             x <- integer
             char '\n'
             return (x,y)


deadCell :: Parser Bool
deadCell = char '.' >-> success False

liveCell :: Parser Bool
liveCell = char '*' >-> success True

plainRow :: Parser [Bool]
plainRow = oneOrMore (deadCell +++ liveCell)

paramRow :: Parser [Bool]
paramRow = do
             n <- nat
             b <- liveCell +++ deadCell
             return (replicate n b)

row :: Parser [Bool]
row = do
        f <- plainRow +++ paramRow
        g <- row
        return (f ++ g)
      +++ return []

ignore :: a -> Parser a
ignore t = zeroOrMore (sat (/= '\n')) >-> char '\n' >-> return t

infoLine :: Parser ()
infoLine = char '#' >-> ignore ()

(>-|) :: Parser a -> Parser b -> Parser [a]
p >-| q = (peak q >-> return []) +++ (p <:> (p >-| q))

inputR f = do
             file <- readFile f
             case parse ((infoLine >-| offset) >-> oneOrMore inputBlock) file of
                  Just(p,s)  -> print p
                  _          -> print "ERROR"

readLife :: FilePath -> IO (World Bool)
readLife f = do
    file <- readFile f
    case parse ((infoLine >-| offset) >-> inputBlock) file of
         Just(p,s) -> case p of
                           B (x,y) (r:rs) -> return $ World (length r -x, length (r:rs))
                                                            (worldify (r:rs)
                                                              (length r - x)
                                                              (length (r:rs)))
                           _              -> error "readLife : wrong format or "
                                                   "unsupported format"
         _         -> error "readLife : wrong format or unsupported format"


worldify :: [[Bool]] -> Int -> Int -> [[Bool]]
worldify []     xs ys = replicate ys (replicate xs False)
worldify (r:rs) xs ys = (r ++ replicate (xs - length r) False) : worldify rs xs ys



data MapBlock = B { topLeft :: Pair, rows :: [[Bool]] }
  deriving (Eq, Show)

inputBlock :: Parser MapBlock
inputBlock = do p <- offset
                m <- oneOrMore (plainRow <-< char '\n')
                return (B p m)

-----------------------------------------------------------------------------
dimensions = do char '('
                c <- specString "cells "       >-> nat
                l <- specString " length "     >-> nat
                w <- specString " width "      >-> nat
                g <- specString " generation " >-> nat
                char ')'
                return (c,l,w,g)

patternName = do char '"'
                 n <- oneOrMore $ sat (/= '"')
                 char '"'
                 return n

comment = char '!' >-> do
                         char ' '
                         patternName
                         char ' '
                         dimensions
                       +++ ignore (0,0,0,0)


{- File structure
  * comments: start with "!"
  * world general info: ! "some-string" (cells <nat> length <nat> width <nat> generation <nat>)
  * offset: <nat>k<nat>h@!
  * row: (<nat>)?("."+"0")*
         trailing: dead
  * empty row: "." == all dead

-}
