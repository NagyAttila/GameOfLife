module Cube where

import Graphics.UI.GLUT

vertex2f :: (GLfloat, GLfloat) -> IO ()
vertex2f (x, y) = vertex $ Vertex2 x y

cube :: GLfloat -> IO ()
cube w = renderPrimitive QuadStrip $ mapM_ vertex2f
         [(x,y) | x <- [w,-w], y <- [w,-w]]