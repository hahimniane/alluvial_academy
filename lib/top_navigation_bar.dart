import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';

class TopNavigationBar extends StatelessWidget {
  const TopNavigationBar({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: <Widget>[
          Row(
            children: [
              Image.asset(
                'assets/logo_navigation_bar.PNG',
                height: 30,
              ),
              const SizedBox(width: 10),
              Text(
                AppLocalizations.of(context)!.connecteam,
                style: TextStyle(
                  color: Colors.blue,
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(width: 20),
              SizedBox(
                width: 200,
                child: TextField(
                  decoration: InputDecoration(
                    hintText: AppLocalizations.of(context)!.searchAnything,
                    prefixIcon: const Icon(Icons.search),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(20.0),
                    ),
                  ),
                ),
              ),
            ],
          ),
          Row(
            children: [
              Text(
                AppLocalizations.of(context)!.theSmallBusinessPlan,
                style: TextStyle(color: Colors.purple),
              ),
              const SizedBox(width: 20),
              Text(
                AppLocalizations.of(context)!.liveWebinars,
                style: TextStyle(color: Colors.blue),
              ),
              const SizedBox(width: 20),
              Text(AppLocalizations.of(context)!.help),
              const SizedBox(width: 10),
              const Icon(Icons.arrow_drop_down),
              const SizedBox(width: 20),
              const Icon(Icons.accessibility),
              const SizedBox(width: 10),
              Stack(
                children: <Widget>[
                  const Icon(Icons.message),
                  Positioned(
                    right: 0,
                    child: Container(
                      padding: const EdgeInsets.all(1),
                      decoration: BoxDecoration(
                        color: Colors.red,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      constraints: const BoxConstraints(
                        minWidth: 12,
                        minHeight: 12,
                      ),
                      child: Text(
                        AppLocalizations.of(context)!.5,
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 8,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(width: 10),
              Stack(
                children: <Widget>[
                  const Icon(Icons.notifications),
                  Positioned(
                    right: 0,
                    child: Container(
                      padding: const EdgeInsets.all(1),
                      decoration: BoxDecoration(
                        color: Colors.red,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      constraints: const BoxConstraints(
                        minWidth: 12,
                        minHeight: 12,
                      ),
                      child: Text(
                        AppLocalizations.of(context)!.1,
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 8,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(width: 20),
              const CircleAvatar(
                backgroundColor: Colors.teal,
                child: Text(AppLocalizations.of(context)!.hn),
              ),
              const SizedBox(width: 10),
              Text(AppLocalizations.of(context)!.hassimiouNiane),
              const Icon(Icons.arrow_drop_down),
            ],
          ),
        ],
      ),
    );
  }
}
