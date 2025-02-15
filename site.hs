{-# Language ScopedTypeVariables #-}
{-# Language OverloadedStrings #-}
{-# Language ViewPatterns #-}
{-# Language BangPatterns #-}

import Hakyll
import Data.List (sortOn)
import Control.Monad (filterM)
import Control.Monad.ListM (sortByM)
import Hakyll.Web.Template (loadAndApplyTemplate)
import System.IO (SeekMode(RelativeSeek))
import Hakyll.Web.Html.RelativizeUrls (relativizeUrls)
import Hakyll.Web.Template.Context (defaultContext)
import Data.Maybe (isJust, fromJust)

--------------------------------------------------------------------------------------------------------
-- MAIN GENERATION -------------------------------------------------------------------------------------
--------------------------------------------------------------------------------------------------------
main :: IO ()
main = hakyll $ do
-- statics ---------------------------------------------------------------------------------------------
    match "assets/css/main.css" $ do
        route   idRoute
        compile compressCssCompiler

    match "assets/**" $ do
        route idRoute
        compile copyFileCompiler

    match "sw.js" $ do
        route idRoute
        compile copyFileCompiler

-- sponsors --------------------------------------------------------------------------------------------
    match "donations/sponsors/*.markdown" $ compile pandocCompiler

-- affiliates ------------------------------------------------------------------------------------------
    match "affiliates/*.markdown" $ compile pandocCompiler
    create ["affiliates/index.html"] $ do
        route idRoute
        compile $ do
            sponsors <- buildSponsorsCtx
            ctx <- affiliatesCtx . sortOn itemIdentifier <$> loadAll "affiliates/*.markdown"

            makeItem ""
                >>= loadAndApplyTemplate "templates/affiliates/list.html"   ctx
                >>= loadAndApplyTemplate "templates/boilerplate.html"       sponsors
                >>= relativizeUrls

-- projects --------------------------------------------------------------------------------------------
    match "projects/*.markdown" $ compile pandocCompiler
    create ["projects/index.html"] $ do
        route idRoute
        compile $ do
            sponsors <- buildSponsorsCtx
            ctx <- projectsCtx . sortOn itemIdentifier <$> loadAll "projects/*.markdown"

            makeItem ""
                >>= loadAndApplyTemplate "templates/projects/list.html" ctx
                >>= loadAndApplyTemplate "templates/boilerplate.html"   sponsors
                >>= relativizeUrls

-- news ------------------------------------------------------------------------------------------------
    match "news/**.markdown" $ compile pandocCompiler
    categories <- buildCategories "news/**.markdown" (fromCapture "news/categories/**.html")

    tagsRules categories $ \category catId ->  compile $ do
        news <- recentFirst =<< loadAll catId
        let ctx =
                listField "news" (newsWithCategoriesCtx categories) (pure news) <>
                dateField "category" "%B %e, %Y"                                <>
                defaultContext

        makeItem ""
            >>= loadAndApplyTemplate "templates/news/tile.html" ctx
            >>= relativizeUrls

    create ["news/index.html"] $ do
        route idRoute
        compile $ do
            sponsors <- buildSponsorsCtx
            newsWithCategories <- recentFirst =<< loadAll "news/categories/**.html"

            let ctx =
                    listField "categories" defaultContext (return newsWithCategories) <>
                    defaultContext

            makeItem ""
                >>= loadAndApplyTemplate "templates/news/list.html"     ctx
                >>= loadAndApplyTemplate "templates/boilerplate.html"   sponsors
                >>= relativizeUrls

-- press -----------------------------------------------------------------------------------------------
    match "press/**.markdown" $ compile pandocCompiler
    create ["news/press/index.html"] $ do
        route idRoute
        compile $ do
            sponsors <- buildSponsorsCtx
            press <- recentFirst =<< loadAll "press/*.markdown"

            let ctx =
                    listField "press_articles" defaultContext (return press) <>
                    defaultContext

            makeItem ""
                >>= loadAndApplyTemplate "templates/press/list.html"    ctx
                >>= loadAndApplyTemplate "templates/boilerplate.html"   sponsors
                >>= relativizeUrls

-- faq ------------------------------------------------------------------------------------------------
    match "faq/*.markdown" $ compile pandocCompiler
    create ["faq/index.html"] $ do
        route idRoute
        compile $ do
            sponsors <- buildSponsorsCtx
            ctx <- faqCtx <$> loadAll "faq/*.markdown"

            makeItem ""
                >>= loadAndApplyTemplate "templates/faq/list.html"      ctx
                >>= loadAndApplyTemplate "templates/boilerplate.html"   sponsors
                >>= relativizeUrls

-- who we are ------------------------------------------------------------------------------------------
    match "who-we-are/people/*.markdown" $ compile pandocCompiler
    create ["who-we-are/index.html"] $ do
        route idRoute
        compile $ do
            sponsors <- buildSponsorsCtx
            ctx <- whoWeAreCtx <$> loadAll "who-we-are/people/*.markdown"

            makeItem ""
                >>= loadAndApplyTemplate "templates/who-we-are/exec-and-board.html" ctx
                >>= loadAndApplyTemplate "templates/boilerplate.html"               sponsors
                >>= relativizeUrls

    create ["who-we-are/past-boards/index.html"] $ do
        route idRoute
        compile $ do
            sponsors <- buildSponsorsCtx
            ctx <- whoWeAreCtx <$> loadAll "who-we-are/people/*.markdown"

            makeItem ""
                >>= loadAndApplyTemplate "templates/who-we-are/past-board.html" ctx
                >>= loadAndApplyTemplate "templates/boilerplate.html"           sponsors
                >>= relativizeUrls

-- podcast ---------------------------------------------------------------------------------------------
    create ["podcast/index.html"] $ do
        route idRoute
        compile $ do
            sponsors <- buildSponsorsCtx
            ctx <- podcastCtx <$> loadAll ("podcast/*/index.markdown" .&&. hasVersion "raw")

            makeItem ""
                >>= loadAndApplyTemplate "templates/podcast/list.html"  ctx
                >>= loadAndApplyTemplate "templates/boilerplate.html"   sponsors
                >>= relativizeUrls

    match "podcast/*/index.markdown" $ do
        route $ setExtension "html"
        compile $ do
            sponsors <- buildSponsorsCtx
            -- extract the captures path fragment. really no easier way?
            episode <- head . fromJust . capture "podcast/*/index.markdown" <$> getUnderlying

            let ctxt = mconcat
                  [ field "transcript" $ \_ -> do
                       loadBody (fromCaptures "podcast/*/transcript.markdown" [episode])
                  , field "links" $ \_ -> do
                       loadBody (fromCaptures "podcast/*/links.markdown" [episode])
                  , defaultContext
                  ]

            pandocCompiler
                >>= applyAsTemplate sponsors
                >>= loadAndApplyTemplate "templates/podcast/episode.html" ctxt
                >>= loadAndApplyTemplate "templates/boilerplate.html"     sponsors
                >>= relativizeUrls

    match "podcast/*/index.markdown" $ version "raw" $ compile pandocCompiler
    match "podcast/*/transcript.markdown" $ compile pandocCompiler
    match "podcast/*/links.markdown" $ compile pandocCompiler

-- general 'static' pages ------------------------------------------------------------------------------
    match ("index.html" .||. "**/index.html") $ do
        route idRoute
        compile $ do
            sponsors <- buildSponsorsCtx
            getResourceBody
                >>= applyAsTemplate sponsors
                >>= loadAndApplyTemplate "templates/boilerplate.html" sponsors
                >>= relativizeUrls

-- resources -------------------------------------------------------------------------------------------
    match "resources/*.markdown" $ compile pandocCompiler
    create ["resources/index.html"] $ do
        route idRoute
        compile $ do
            sponsors <- buildSponsorsCtx
            resources <- loadAll "resources/*.markdown"

            let ctx =
                    listField "resources" defaultContext (return resources) <>
                    defaultContext

            makeItem ""
                >>= loadAndApplyTemplate "templates/resources/list.html"    ctx
                >>= loadAndApplyTemplate "templates/boilerplate.html"       sponsors
                >>= relativizeUrls

-- templates -------------------------------------------------------------------------------------------
    match "templates/*" $ compile templateBodyCompiler
    match "templates/**" $ compile templateBodyCompiler


--------------------------------------------------------------------------------------------------------
-- CONTEXT ---------------------------------------------------------------------------------------------
--------------------------------------------------------------------------------------------------------

-- sponsors --------------------------------------------------------------------------------------------

buildSponsorsCtx :: Compiler (Context String)
buildSponsorsCtx = sponsorsCtx . sortOn itemIdentifier <$> loadAll "donations/sponsors/*.markdown"

-- | Partition sponsors into by level: monad, applicative, and functor
-- Sponsors are listed in the footer template, which means we need this
-- context for most pages.
sponsorsCtx :: [Item String] -> Context String
sponsorsCtx sponsors =
    listField "monads" defaultContext (ofMetadataField "level" "Monad" sponsors)             <>
    listField "applicatives" defaultContext (ofMetadataField "level" "Applicative" sponsors) <>
    listField "functors" defaultContext (ofMetadataField "level" "Functor" sponsors)         <>
    defaultContext

-- affiliates ------------------------------------------------------------------------------------------
-- | Partition affiliates into affiliates and pending
affiliatesCtx :: [Item String] -> Context String
affiliatesCtx affiliates =
    listField "affiliated" defaultContext (ofMetadataField "status" "affiliated" affiliates)  <>
    listField "pending" defaultContext (ofMetadataField "status" "pending" affiliates)        <>
    defaultContext

-- projects --------------------------------------------------------------------------------------------
-- | Partition projects into : Ideation | Proposed | In Progress | Completed
projectsCtx :: [Item String] -> Context String
projectsCtx projects =
    listField "ideas" defaultContext (ofMetadataField "status" "ideation" projects)        <>
    listField "proposals" defaultContext (ofMetadataField "status" "proposed" projects)    <>
    listField "inprogress" defaultContext (ofMetadataField "status" "inprogress" projects) <>
    listField "completed" defaultContext (ofMetadataField "status" "completed" projects)   <>
    defaultContext

-- news ------------------------------------------------------------------------------------------------
-- | build group of news inside date of publishing (category)
newsWithCategoriesCtx :: Tags -> Context String
newsWithCategoriesCtx categories =
    listField "categories" categoryCtx getAllCategories <>
    defaultContext
        where
            getAllCategories :: Compiler [Item (String, [Identifier])]
            getAllCategories = pure . map buildItemFromTag $ tagsMap categories
                where
                    buildItemFromTag :: (String, [Identifier]) -> Item (String, [Identifier])
                    buildItemFromTag c@(name, _) = Item (tagsMakeId categories name) c
            categoryCtx :: Context (String, [Identifier])
            categoryCtx =
                listFieldWith "news" newsCtx getNews        <>
                metadataField                               <>
                urlField "url"                              <>
                pathField "path"                            <>
                titleField "title"                          <>
                missingField
                    where
                        getNews:: Item (String, [Identifier]) -> Compiler [Item String]
                        getNews (itemBody -> (_, ids)) = mapM load ids
                        newsCtx :: Context String
                        newsCtx = newsWithCategoriesCtx categories

-- faq -------------------------------------------------------------------------------------------------
faqCtx :: [Item String] -> Context String
faqCtx entries =
    listField "faq_entries" defaultContext (sortFromMetadataField "order" entries) <>
    defaultContext

-- who we are ------------------------------------------------------------------------------------------
whoWeAreCtx :: [Item String] -> Context String
whoWeAreCtx people =
    listField "currentexecutiveteam" defaultContext (ofMetadataFieldCurrent True "executiveTeam" "True" people) <>
    listField "currentboard" defaultContext (ofMetadataFieldCurrent True "executiveTeam" "False" people)        <>
    listField "pastexecutiveteam" defaultContext (ofMetadataFieldCurrent False "executiveTeam" "True" people)   <>
    listField "pastboard" defaultContext  (ofMetadataFieldCurrent False "executiveTeam" "False" people)         <>
    listField "interimboard" defaultContext (ofMetadataField "interimBoard" "True" people)                      <>
    defaultContext
    where
        ofMetadataFieldCurrent :: Bool -> String -> String -> [Item String] -> Compiler [Item String]
        ofMetadataFieldCurrent cur field value items = do
            items' <- ofMetadataField field value items
            filterM (\item -> do
                mbTenureStart <- getMetadataField (itemIdentifier item) "tenureStart"
                mbTenureStop <- getMetadataField (itemIdentifier item) "tenureEnd"
                pure $ case mbTenureStop of
                    Nothing -> cur && isJust mbTenureStart
                    Just date -> not cur
             ) items'

-- podcast ---------------------------------------------------------------------------------------------
podcastCtx :: [Item String] -> Context String 
podcastCtx episodes =
    listField "episodes" defaultContext (return $ reverse episodes) <>
    defaultContext

--------------------------------------------------------------------------------------------------------
-- UTILS -----------------------------------------------------------------------------------------------
--------------------------------------------------------------------------------------------------------

-- | filter list of item string based on the given value to match on the given metadata field
ofMetadataField :: String -> String -> [Item String] -> Compiler [Item String]
ofMetadataField field value = filterM (\item -> do
        mbStatus <- getMetadataField (itemIdentifier item) field
        return $ Just value == mbStatus
    )

-- | sort list of item based on the given metadata field
sortFromMetadataField :: String -> [Item String] -> Compiler [Item String]
sortFromMetadataField field = sortByM (\a b -> do
        a' <- getMetadataField (itemIdentifier a) field
        b' <- getMetadataField (itemIdentifier b) field
        return $ compare a' b'
    )
