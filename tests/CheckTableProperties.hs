{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE QuasiQuotes #-}
{-# LANGUAGE ScopedTypeVariables #-}

module CheckTableProperties
  ( checkTableProperties,
  )
where

import Control.DeepSeq (force)
import Control.Exception (evaluate)
import Core.Text
import FormatDocument (markdownToPandoc)
import PandocToMarkdown
  ( NotSafe,
    Rectangle (..),
    buildRow,
    combineRectangles,
    heightOf,
    pandocToMarkdown,
    rectanglerize,
    tableToMarkdown,
  )
import Test.Hspec
import Text.Pandoc (Alignment (..), Block (..), Inline (..))

notsafe :: Selector NotSafe
notsafe = const True

checkTableProperties :: Spec
checkTableProperties = do
  describe "Table rendering code" $ do
    it "Making wrapped text into rectangles" $
      rectanglerize 6 AlignLeft "First Name"
        `shouldBe` Rectangle
          6
          2
          [ "First ",
            "Name  "
          ]

    it "Rectanglerizing a block with too long lines should throw" $
      (evaluate . force) (rectanglerize 7 AlignLeft "Borough of Kensington") `shouldThrow` notsafe

    it "Two rectangles of equal size combine" $
      let rect1 = rectanglerize 8 AlignLeft "This is a test"
          rect2 = rectanglerize 8 AlignLeft "Ode to Joy"
          result = combineRectangles rect1 rect2
       in do
            heightOf rect1 `shouldBe` 2
            heightOf rect2 `shouldBe` 2
            heightOf result `shouldBe` 2
            result
              `shouldBe` Rectangle
                16
                2
                [ "This is Ode to  ",
                  "a test  Joy     "
                ]

    it "Two rectangles of unequal size combine (1)" $
      let --                        1234567890
          rect1 = rectanglerize 10 AlignLeft "Emergency Broadcast System"
          rect2 = rectanglerize 10 AlignLeft "Ode to Joy is nice"
          result = combineRectangles rect1 rect2
       in do
            heightOf rect1 `shouldBe` 3
            heightOf rect2 `shouldBe` 2
            heightOf result `shouldBe` 3
            result
              `shouldBe` Rectangle
                20
                3
                [ "Emergency Ode to Joy",
                  "Broadcast is nice   ",
                  "System              "
                ]

    it "Two rectangles of unequal size combine (2)" $
      let --                        1234567890
          rect3 = rectanglerize 10 AlignLeft "This is an emergency"
          rect4 = rectanglerize 10 AlignLeft "Ode to Joy is nice piece that lots play"
          result = combineRectangles rect3 rect4
       in do
            heightOf rect3 `shouldBe` 2
            heightOf rect4 `shouldBe` 4
            heightOf result `shouldBe` 4
            result
              `shouldBe` Rectangle
                20
                4
                [ "This is anOde to Joy",
                  "emergency is nice   ",
                  "          piece that",
                  "          lots play "
                ]

    it "Given several cells, builds a row" $
      let cell1 =
            Rectangle
              10
              3
              [ "This is an",
                "emergency ",
                "no problem"
              ]
          cell2 =
            Rectangle
              10
              4
              [ "Ode to Joy",
                "is nice   ",
                "piece that",
                "lots play "
              ]
          result = buildRow [10, 10] [cell1, cell2]
       in do
            result
              `shouldBe` "This is an Ode to Joy\n"
              <> "emergency  is nice   \n"
              <> "no problem piece that\n"
              <> "           lots play "

    it "Header rows format" $
      let result =
            tableToMarkdown
              []
              [AlignLeft, AlignLeft, AlignLeft]
              [0.3, 0.3, 0.3]
              [ [Plain [Str "First"]],
                [Plain [Str "Second"]],
                [Plain [Str "Third"]]
              ]
              []
       in do
            result
              `shouldBe` [quote|
-----------------------------------------------------------------------
First                   Second                  Third                  
----------------------- ----------------------- -----------------------

-----------------------------------------------------------------------
            |]

    it "A minimal complete example reformats properly" $
      let table =
            [quote|
| First | Second | Third |
|------:|:----:|---------|
|   1  |  2  |  3   |
            |]
       in do
            doc <- markdownToPandoc table
            let result = pandocToMarkdown doc
            result
              `shouldBe` [quote|
--------------------------------------------
         First     Second     Third         
-------------- -------------- --------------
             1       2        3             
--------------------------------------------
            |]
