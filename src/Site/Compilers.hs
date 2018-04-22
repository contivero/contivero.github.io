{-# LANGUAGE OverloadedStrings #-}

module Site.Compilers
    ( pandocMathCompiler
    , sassCompiler
    ) where

import           Data.Monoid ((<>))
import           Hakyll
import           Text.Pandoc.Options


pandocMathCompiler = pandocCompilerWith defaultHakyllReaderOptions writerOptions
  where mathExtensions = extensionsFromList
                         [Ext_tex_math_dollars, Ext_tex_math_double_backslash, Ext_latex_macros]
        defaultExtensions = writerExtensions defaultHakyllWriterOptions
        writerOptions = defaultHakyllWriterOptions {
                          writerExtensions = defaultExtensions <> mathExtensions,
                          writerHTMLMathMethod = MathJax ""
                        }

sassCompiler :: Compiler (Item String)
sassCompiler = fmap (fmap compressCss) $
    getResourceString >>= withItemBody (unixFilter "sass" ["--stdin", "--style=compressed"])
