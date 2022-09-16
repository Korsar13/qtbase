#pragma once

#include <QtGlobal>
#include <QTextCharFormat>
#include <QTextBlockFormat>
#include <QTextLayout>
#include <map>

#ifndef _Q_WIDGETS_EXPORT
  #include <QtWidgets/qtwidgetsglobal.h>
  #define _Q_WIDGETS_EXPORT Q_WIDGETS_EXPORT 
#endif


namespace Akvis {

class _Q_WIDGETS_EXPORT sDefaultParamsTC
{
public:
  QString fontFamily;
  int     fontSize;
  int     fontWeight;
  bool    fontItalic;
  QColor  fontColor;
  int     fontCapitalization;
  int     fontVertAlignment;
  bool    fontUnderline;
  bool    fontStrikeOut;
  bool    fontAntialias;
  int     horzAlign;
  int     marginLeft;
  int     marginRight;
  int     intendFirstLine;

  sDefaultParamsTC();

  void FillTo( bool isFixedBounds, QTextCharFormat& charFmt, QTextBlockFormat& blockFmt ) const;
  void SetFrom( const QTextCharFormat& charFmt, const QTextBlockFormat& blockFmt );
};

_Q_WIDGETS_EXPORT bool ValidateProperties( QTextCharFormat& charFmt );


} // namespace Akvis
