#pragma once

#include <map>
#include <QTextLayout>
#include <QPainterPath>

#ifdef __APPLE__
# undef qDebug
#endif

#ifndef _Q_GUI_EXPORT
#define _Q_GUI_EXPORT Q_GUI_EXPORT 
#endif

namespace Akvis {

struct sGlyphPath {
  QChar  C;
  double BaseLine;
  QPainterPath PP;
};

// Преобразует текст в побуквенный путь
_Q_GUI_EXPORT void TextLayout2Path( const QTextLayout* textLayout, const QPointF& pos, const QRectF& clip, std::vector< std::pair< QRgb, sGlyphPath > >& result );

} // namespace Akvis
