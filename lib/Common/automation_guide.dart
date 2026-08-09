import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:akonssquare/Common/database_service.dart';

class AutomationGuidePage extends StatelessWidget {
  const AutomationGuidePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Automation Guide"),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Card(
              color: Colors.deepPurple,
              child: Padding(
                padding: EdgeInsets.all(16.0),
                child: Row(
                  children: [
                    Icon(Icons.info_outline, color: Colors.white),
                    SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        "এই পেজটি শুধুমাত্র ডেভেলপমেন্ট পিরিয়ডে আপনার সাহায্যের জন্য তৈরি করা হয়েছে। কাজ শেষ হলে এটি মুছে ফেলা হবে।",
                        style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),
            Text(
              "মাস্টার কমান্ড সমূহ:",
              style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            _buildMasterCommandRow(
              context,
              command: "[CMD: ACTIVATE_BANGLA_LOCALIZATION]",
              description: "এই কমান্ডটি দিলে আমি পুরো অ্যাপের ভাষা ইংরেজি থেকে বাংলায় পরিবর্তন করার কাজ শুরু করব। এটি অ্যাপের প্রতিটি বাটন, টাইটেল এবং মেসেজকে বাংলায় অনুবাদ করে দেবে। কাজ শুরু করার আগে আমি আপনার কাছে অনুমতি চেয়ে নেব।",
            ),
            const SizedBox(height: 24),
            Text(
              "* নির্দেশিকা:",
              style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            const Text(
              "১. উপরের কমান্ডটি কপি করুন।\n"
              "২. আমার (ডেভেলপমেন্ট এজেন্ট) সাথে চ্যাট বক্সে এটি পেস্ট করুন।\n"
              "৩. আমি কমান্ডটি পড়ার পর আপনার কাছ থেকে কাজ শুরু করার অনুমতি চাইব।",
              style: TextStyle(fontSize: 13, color: Colors.grey),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMasterCommandRow(BuildContext context, {required String command, required String description}) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.deepPurple.withOpacity(0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.deepPurple.withOpacity(0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.code, size: 18, color: Colors.deepPurple),
              const SizedBox(width: 8),
              Expanded(
                child: SelectableText(
                  command,
                  style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.deepPurple, fontFamily: 'monospace'),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.copy, size: 16),
                onPressed: () {
                  Clipboard.setData(ClipboardData(text: command));
                  DatabaseService.showToast(context, "কমান্ড কপি করা হয়েছে!");
                },
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            description,
            style: const TextStyle(fontSize: 13, height: 1.5),
          ),
        ],
      ),
    );
  }
}
