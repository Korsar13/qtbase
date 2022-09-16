#ifndef _DEF_AKVIS_TEXTCONTROL
#define _DEF_AKVIS_TEXTCONTROL

#include "AkvisTextControlDefP.h"

#ifdef __APPLE__
# undef qDebug
#endif

#include "private/qwidgettextcontrol_p.h"
typedef QWidgetTextControl _QWidgetTextControl;
#ifndef _Q_WIDGETS_EXPORT
  #define _Q_WIDGETS_EXPORT Q_WIDGETS_EXPORT 
#endif

namespace Akvis {

class _Q_WIDGETS_EXPORT AkvisTextControl : public _QWidgetTextControl {
  Q_OBJECT
public:
  AkvisTextControl( QTextDocument *doc, QObject *parent, sDefaultParamsTC& defaultParams );

  virtual void timerEvent( QTimerEvent* e );

  bool hasSelection() const;
  void clearSelection();
  
  bool IsCaretOn() const;

  void setHasFocus();
  void setBlinkingCaretEnabled( bool enable );

  void setCursorPosition( const QPointF &pos );

  virtual void insertFromMimeData( const QMimeData *source );

signals:
  void blinkCaret( bool on );

public:
  const sDefaultParamsTC &m_DefaultParams;
};

} // namespace Akvis

#endif //_DEF_AKVIS_TEXTCONTROL
