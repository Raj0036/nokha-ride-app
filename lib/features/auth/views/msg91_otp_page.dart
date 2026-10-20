import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';

class Msg91OtpPage extends StatefulWidget {
  const Msg91OtpPage({super.key, required this.initialPhone});
  final String initialPhone;

  @override
  State<Msg91OtpPage> createState() => _Msg91OtpPageState();
}

class _Msg91OtpPageState extends State<Msg91OtpPage> {
  static const _widgetId = String.fromEnvironment('MSG91_WIDGET_ID');
  static const _widgetToken = String.fromEnvironment('MSG91_WIDGET_TOKEN');
  WebViewController? _controller;
  String? _error;
  bool _ready = false;
  bool _returned = false;

  bool get _configured => _widgetId.isNotEmpty && _widgetToken.isNotEmpty &&
      !_widgetId.startsWith('YOUR_') && !_widgetToken.startsWith('YOUR_');

  @override
  void initState() {
    super.initState();
    if (!_configured) {
      _error = 'MSG91 Widget is not configured. Set MSG91_WIDGET_ID and MSG91_WIDGET_TOKEN in the local build configuration.';
      return;
    }
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..addJavaScriptChannel('NokhaRideOtp', onMessageReceived: _onMessage)
      ..setNavigationDelegate(NavigationDelegate(
        onPageFinished: (_) { if (mounted) setState(() => _ready = true); },
        onWebResourceError: (error) {
          if (error.isForMainFrame == true && mounted) {
            setState(() => _error = 'Unable to load MSG91 verification. Check internet and retry.');
          }
        },
      ))
      ..loadHtmlString(_html, baseUrl: 'https://verify.msg91.com');
  }

  String get _html {
    final id = jsonEncode(_widgetId);
    final token = jsonEncode(_widgetToken);
    final phone = jsonEncode('91${widget.initialPhone}');
    final initialPhone = widget.initialPhone;
    return '''
<!doctype html><html><head><meta charset="utf-8">
<meta name="viewport" content="width=device-width,initial-scale=1,maximum-scale=1">
<style>
*{box-sizing:border-box}body{font-family:Arial,sans-serif;color:#17221a;margin:0;padding:20px}
h2{font-size:23px;margin:4px 0 8px}p{color:#58645d;line-height:1.5;font-size:14px}
label{display:block;font-size:13px;font-weight:600;margin:18px 0 7px}
input{width:100%;padding:14px;border:1px solid #cbd5ce;border-radius:10px;font-size:17px}
button{width:100%;border:0;border-radius:10px;background:#16834a;color:white;font-weight:700;font-size:15px;padding:14px;margin-top:14px}
button.secondary{background:#eaf5ee;color:#12653b}#otpArea{display:none}
#status{min-height:24px;margin-top:12px;font-size:13px;color:#12653b;overflow-wrap:anywhere}
</style></head><body>
<h2>Verify your mobile</h2><p>Enter the OTP sent to your mobile number.</p>
<label for="mobile">Mobile number</label>
<input id="mobile" value="$initialPhone" readonly>
<button id="sendBtn" onclick="sendOtpNow()">Send OTP</button>
<div id="otpArea"><label for="otp">Verification code</label>
<input id="otp" inputmode="numeric" autocomplete="one-time-code" maxlength="8" placeholder="Enter OTP">
<button onclick="verifyOtpNow()">Verify and continue</button>
<button class="secondary" onclick="resendOtpNow()">Resend OTP</button></div>
<div id="status" role="status"></div><p>Never share your verification code.</p>
<script>
const widgetId=$id, tokenAuth=$token, identifier=$phone;
let reqId='', sent=false, finished=false;
function status(text, bad){const el=document.getElementById('status');el.textContent=text||'';el.style.color=bad?'#b42318':'#12653b';}
function req(value, depth=0){
 if(depth>5||value==null)return '';
 if(typeof value==='string'){if(/^[A-Za-z0-9_-]{16,80}\$/.test(value)&&value.split('.').length!==3)return value;try{return req(JSON.parse(value),depth+1)}catch(_){return ''}}
 if(typeof value!=='object')return '';
 for(const k of ['reqId','req_id','requestId','request_id'])if(typeof value[k]==='string'&&value[k].length>=8)return value[k];
 for(const k of ['data','message','result','response']){const x=req(value[k],depth+1);if(x)return x}
 return '';
}
function token(value, depth=0){
 if(depth>6||value==null)return '';
 if(typeof value==='string'){if(/^[A-Za-z0-9_-]+\\.[A-Za-z0-9_-]+\\.[A-Za-z0-9_-]+\$/.test(value))return value;try{return token(JSON.parse(value),depth+1)}catch(_){return ''}}
 if(typeof value!=='object')return '';
 for(const k of ['accessToken','access-token','access_token','token','message','data','result','response']){const x=token(value[k],depth+1);if(x)return x}
 return '';
}
function verified(data){if(finished)return;const t=token(data);if(!t){status('MSG91 did not return a valid access token. Retry verification.',true);return}finished=true;status('Phone verified. Connecting securely…');window.NokhaRideOtp.postMessage(JSON.stringify({type:'verified',accessToken:t}));}
function failure(error){const message=typeof error==='string'?error:(error&&(error.message||error.error))||'Verification failed. Try again.';status(String(message).slice(0,160),true)}
function sentOtp(data){reqId=req(data);if(!reqId){status('MSG91 did not return an OTP request ID. Please retry.',true);return}sent=true;document.getElementById('otpArea').style.display='block';document.getElementById('sendBtn').style.display='none';status('OTP sent. Check your mobile and enter the code.')}
function sendOtpNow(){if(!window.sendOtp){status('MSG91 is still loading. Wait a moment.',true);return}status('Sending OTP…');window.sendOtp(identifier,sentOtp,failure)}
function verifyOtpNow(){const otp=document.getElementById('otp').value.trim();if(!sent||!reqId){status('Send an OTP first.',true);return}if(!/^[0-9]{4,8}\$/.test(otp)){status('Enter the OTP from your message.',true);return}status('Verifying OTP…');window.verifyOtp(otp,verified,failure,reqId)}
function resendOtpNow(){if(!sent||!reqId||!window.retryOtp){status('Send an OTP first.',true);return}status('Requesting a new OTP…');window.retryOtp(null,function(data){const next=req(data);if(next)reqId=next;status('A new OTP has been requested.')},failure,reqId)}
const configuration={widgetId:widgetId,tokenAuth:tokenAuth,identifier:identifier,exposeMethods:true,success:verified,failure:failure};
const script=document.createElement('script');script.src='https://verify.msg91.com/otp-provider.js';
script.onload=function(){try{window.initSendOTP(configuration)}catch(_){status('MSG91 could not initialize. Check Widget ID and Widget Token.',true)}};
script.onerror=function(){status('Unable to load MSG91 SDK. Check your internet connection.',true)};
document.head.appendChild(script);
</script></body></html>
''';
  }

  void _onMessage(JavaScriptMessage message) {
    if (_returned) return;
    try {
      final value = jsonDecode(message.message);
      if (value is Map && value['type'] == 'verified') {
        final accessToken = value['accessToken'];
        if (accessToken is String && accessToken.isNotEmpty) {
          _returned = true;
          Navigator.of(context).pop(accessToken);
          return;
        }
      }
    } catch (_) {}
    if (mounted) setState(() => _error = 'Could not read the MSG91 verification response.');
  }

  @override
  Widget build(BuildContext context) {
    if (!_configured) {
      return Scaffold(appBar: AppBar(title: const Text('Phone verification')),
        body: Center(child: Padding(padding: const EdgeInsets.all(24), child: Text(_error ?? 'MSG91 is not configured.'))));
    }
    return Scaffold(appBar: AppBar(title: const Text('Phone verification')),
      body: Stack(children: [
        WebViewWidget(controller: _controller!),
        if (!_ready && _error == null) const Center(child: CircularProgressIndicator()),
        if (_error != null) Center(child: Padding(padding: const EdgeInsets.all(24), child: Text(_error!, textAlign: TextAlign.center))),
      ]));
  }
}
