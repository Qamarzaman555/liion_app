import 'dart:io';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:syncfusion_flutter_pdfviewer/pdfviewer.dart';
import 'package:liion_app/app/core/constants/app_colors.dart';
import '../controllers/manual_controller.dart';

class ManualView extends GetView<ManualController> {
  const ManualView({super.key});

  @override
  Widget build(BuildContext context) {
    final pdfViewerController = PdfViewerController();
    final pdfViewerKey = GlobalKey<SfPdfViewerState>();

    return Scaffold(
      resizeToAvoidBottomInset: false,
      backgroundColor: AppColors.whiteColor,
      appBar: AppBar(
        backgroundColor: AppColors.whiteColor,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(
            Icons.arrow_back,
            size: 30,
          ),
          onPressed: () {
            Get.back();
          },
          color: AppColors.blackColor,
        ),
      ),
      body: SafeArea(
        child: Obx(() {
          final pdfPath = controller.fullPathOfPdf.value;
          final isOffline = controller.isOfflineMode.value;

          if (pdfPath.isEmpty) {
            return const Center(
              child: CircularProgressIndicator(
                color: AppColors.primaryColor,
              ),
            );
          }

          // Check if the file exists before trying to display it
          final file = File(pdfPath);
          if (!file.existsSync()) {
            return const Center(
              child: Text("PDF file not found. Retrying download..."),
            );
          }

          return Stack(
            children: [
              KeyedSubtree(
                key: ValueKey(pdfPath),
                child: SfPdfViewer.file(
                  file,
                  key: pdfViewerKey,
                  controller: pdfViewerController,
                  canShowScrollHead: false,
                  canShowScrollStatus: false,
                  canShowPaginationDialog: false,
                  pageSpacing: 4.0,
                  enableDoubleTapZooming: true,
                  canShowPageLoadingIndicator: false,
                  onDocumentLoadFailed: (PdfDocumentLoadFailedDetails details) {
                    print(
                        'PDF load failed: ${details.error}, ${details.description}');
                  },
                  onDocumentLoaded: (PdfDocumentLoadedDetails details) {
                    // Document loaded successfully
                  },
                ),
              ),
              if (isOffline)
                Positioned(
                  top: 8,
                  right: 8,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.orange.withOpacity(0.9),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.offline_pin,
                          color: Colors.white,
                          size: 16,
                        ),
                        SizedBox(width: 4),
                        Text(
                          'Offline Mode',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          );
        }),
      ),
    );
  }
}


