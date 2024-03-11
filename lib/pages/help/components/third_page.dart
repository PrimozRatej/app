import 'package:flutter/material.dart';
import 'package:humhub/components/ease_out_container.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:humhub/util/const.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';

class ThirdPage extends StatelessWidget {
  final bool fadeIn;
  const ThirdPage({Key? key, required this.fadeIn}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 50),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 10),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                AppLocalizations.of(context)!.more_info_title,
                style: getHeaderStyle(context),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 10),
            child: Text(AppLocalizations.of(context)!.more_info_first_par, style: paragraphStyle),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 10),
            child: Text(AppLocalizations.of(context)!.more_info_second_par, style: paragraphStyle),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 10),
            child: Text(AppLocalizations.of(context)!.more_info_third_par, style: paragraphStyle),
          ),
          const SizedBox(
            height: 40,
          ),
          EaseOutContainer(
            fadeIn: fadeIn,
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 20),
              child: Center(
                child: Container(
                  width: MediaQuery.of(context).size.width / 1.5,
                  height: 50,
                  decoration: BoxDecoration(borderRadius: BorderRadius.circular(5)),
                  child: TextButton(
                    style: ButtonStyle(
                      backgroundColor: MaterialStateProperty.resolveWith<Color>(
                        (Set<MaterialState> states) {
                          return primaryColor;
                        },
                      ),
                    ),
                    onPressed: () {
                      launchUrl(Uri.parse(AppLocalizations.of(context)!.more_info_pro_edition_url), mode: LaunchMode.platformDefault);
                    },
                    child: Center(
                      child: Text(
                        AppLocalizations.of(context)!.more_info_pro_edition,
                        style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.normal),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
