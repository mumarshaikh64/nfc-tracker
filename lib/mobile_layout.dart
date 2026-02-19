import 'package:flutter/material.dart';
import 'package:nfc_tracker/add_mobile_form.dart';
import 'package:nfc_tracker/view_mobile.dart';

class MobileLayout extends StatefulWidget {
  final Function(bool) onWrite;
  const MobileLayout({super.key, required this.onWrite});

  @override
  State<MobileLayout> createState() => _MobileLayoutState();
}

class _MobileLayoutState extends State<MobileLayout> {
  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, con) {
      final width = con.maxWidth;
      final height = con.maxHeight;
      return DefaultTabController(
        initialIndex: 0,
        length: 2,
        child: Scaffold(
          appBar: AppBar(
            backgroundColor: const Color.fromARGB(255, 56, 56, 146),
            title: Text("NFC Passport Reader",
                style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: Colors.white)),
            bottom: TabBar(
                indicatorColor: Colors.white,
                labelColor: Colors.white,
                unselectedLabelColor: const Color.fromARGB(255, 197, 197, 197),
                tabs: [
                  Tab(text: "Read"),
                  Tab(
                    text: "Write",
                  )
                ]),
          ),
          body: Container(
            width: width,
            height: height,
            child: TabBarView(children: [
              ViewRecordMobile(nfcData: {}, onRefresh: () {}),
              AddRecordMobile(onWrite: widget.onWrite)
            ]),
          ),
        ),
      );
    });
  }
}
