#include "AkvisQtGui.h"
#include <qtextlayout.h>
#include <private/qtextengine_p.h>
#include <private/qfontengine_p.h>
#include <private/qfont_p.h>

#ifdef __APPLE__
# undef qDebug
#endif

namespace Akvis {

static QFontEngine* EngineForScript( const QFont& font,  int script) {
  return QFontPrivate::get( font )->engineForScript( script );
}

static void QTextLine_draw( QTextEngine* eng, int index, const QPointF &posPt, std::vector< std::pair< QRgb, sGlyphPath > >& result ) {
  eng->clearDecorations();
  eng->enableDelayDecorations();

  const QScriptLine &line = eng->lines[index];
  QFixed lineBase = line.base();
  const QFixed y = QFixed::fromReal( posPt.y() ) + line.y + lineBase;

  QTextLineItemIterator I( eng, index, posPt, nullptr );
  while( !I.atEnd() ) {
    QScriptItem &si = I.next();

    if( si.analysis.flags == QScriptAnalysis::LineOrParagraphSeparator || si.analysis.flags >= QScriptAnalysis::TabOrObject ) continue;

    QFixed itemBaseLine = y;
    QFont f( eng->font( si ) );

    QRgb key = qRgb( 0,0,0 );
    QTextCharFormat format;
    if( eng->hasFormats() ) {
      format = eng->format( &si );
      QBrush c = format.foreground();
      if( c.style() != Qt::NoBrush ) {
        key = c.color().rgba();
      }
      QTextCharFormat::VerticalAlignment valign = format.verticalAlignment();
      if( valign == QTextCharFormat::AlignSuperScript || valign == QTextCharFormat::AlignSubScript ) {
        const QFontEngine *fe = EngineForScript( f, si.analysis.script );
        QFixed height = fe->ascent() + fe->descent();
        if( valign == QTextCharFormat::AlignSubScript )
          itemBaseLine += height / 6;
        else if (valign == QTextCharFormat::AlignSuperScript)
          itemBaseLine -= height / 2;
      }
    }

    unsigned short *logClusters = eng->logClusters( &si );
    QGlyphLayout glyphs( eng->shapedGlyphs( &si ) );
    QFixed gfwidth(0);
    for( auto glyphsStart = I.glyphsStart, itemStart = I.itemStart; glyphsStart < I.glyphsEnd; ++glyphsStart, ++itemStart ) {
      QTextItemInt gf(
			  glyphs.mid( glyphsStart, 1 ),
			  &f, 
			  eng->layoutData->string.unicode() + itemStart, 1,
			  eng->fontEngine( si ), format
		  );
      gf.logClusters = logClusters + itemStart - si.position;
      gf.width       = glyphs.effectiveAdvance( glyphsStart );
      gf.justified   = line.justified;
      gf.initWithScriptItem(si);
      Q_ASSERT( gf.fontEngine );

      QPointF pos( I.x.toReal() + gfwidth.toReal(), itemBaseLine.toReal() );
      sGlyphPath gp;
      gp.C = eng->layoutData->string.unicode()[ itemStart ];
      gp.BaseLine = itemBaseLine.toReal();
      gp.PP.setFillRule( Qt::WindingFill );
      if( gf.glyphs.numGlyphs ) {
        gf.fontEngine->addOutlineToPath( pos.x(), pos.y(), gf.glyphs, &gp.PP, gf.flags );
        if( gf.flags ) {
          const QFontEngine *fe = gf.fontEngine;
          const qreal lw = fe->lineThickness().toReal();
          if (gf.flags & QTextItem::Underline) {
            qreal offs = fe->underlinePosition().toReal();
            gp.PP.addRect(pos.x(), pos.y() + offs, gf.width.toReal(), lw);
          }
          if (gf.flags & QTextItem::Overline) {
            qreal offs = fe->ascent().toReal() + 1;
            gp.PP.addRect(pos.x(), pos.y() - offs, gf.width.toReal(), lw);
          }
          if (gf.flags & QTextItem::StrikeOut) {
            qreal offs = fe->ascent().toReal() / 3;
            gp.PP.addRect(pos.x(), pos.y() - offs, gf.width.toReal(), lw);
          }
        }
        result.push_back( std::make_pair( key, gp ) );
      }
      gfwidth+=gf.width;
    }
  }
}

void TextLayout2Path( const QTextLayout* textLayout, const QPointF& pos, const QRectF& clip, std::vector< std::pair< QRgb, sGlyphPath > >& result ) {
  QTextEngine *eng = textLayout->engine();
  if( eng->lines.isEmpty() ) return;

  if( !eng->layoutData ) eng->itemize();

  QPointF position = pos + eng->position;
  QFixed clipy = (INT_MIN/256);
  QFixed clipe = (INT_MAX/256);
  if( clip.isValid() ) {
    clipy = QFixed::fromReal( clip.y() - position.y() );
    clipe = clipy + QFixed::fromReal( clip.height() );
  }
  int firstLine = 0;
  int lastLine = eng->lines.size();
  for( int i = 0, n = lastLine; i < n; ++i ) {
    const QScriptLine &sl = eng->lines[i];
    if( sl.y > clipe ) {
      lastLine = i;
      break;
    }
    if( ( sl.y + sl.height() ) < clipy ) {
      firstLine = i;
      continue;
    }
  }

  for( int line = firstLine; line < lastLine; ++line ) {
    QTextLine_draw( eng, line, position, result );
  }

  if( !eng->cacheGlyphs ) eng->freeMemory();
}


} // namespace Akvis
