import 'package:alluwalacademyadmin/widgets/export_widget.dart';
import 'package:flutter/material.dart';
import 'package:alluwalacademyadmin/const.dart';
import 'package:syncfusion_flutter_datepicker/datepicker.dart'; // Assuming you have this package for the text style
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:syncfusion_flutter_datagrid/datagrid.dart';
import 'package:syncfusion_flutter_core/theme.dart';
import 'package:csv/csv.dart';
import 'package:universal_html/html.dart' as html;

import 'add_new_user_screen.dart';
import 'const.dart';
import 'header_widget.dart';
import 'model/employee_model_class.dart';

class TimeClockScreen extends StatefulWidget {
  @override
  _TimeClockScreenState createState() => _TimeClockScreenState();
}

class _TimeClockScreenState extends State<TimeClockScreen> {
  bool _isHovered = false;
  PickerDateRange? _selectedDateRange;

  Future<void> _selectDateRange(BuildContext context) async {
    final DateTimeRange? picked = await showDialog<DateTimeRange>(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: Colors.white,
          contentPadding: const EdgeInsets.all(16.0),
          content: Container(
            width: 400,
            height: 400,
            color: Colors.white,
            child: Column(
              children: [
                Expanded(
                  child: SfDateRangePicker(
                    backgroundColor: Colors.white,
                    onSelectionChanged: _onSelectionChanged,
                    selectionMode: DateRangePickerSelectionMode.range,
                  ),
                  // child: CalendarDatePicker(
                  //   initialDate: tempPickedRange.start,
                  //   firstDate: DateTime(2020),
                  //   lastDate: DateTime(2030),
                  //   onDateChanged: (newDate) {
                  //     setState(() {
                  //       tempPickedRange =
                  //           DateTimeRange(start: newDate, end: newDate);
                  //     });
                  //   },
                  // ),
                ),
                // ElevatedButton(
                //   onPressed: () {
                //     setState(() {
                //       _selectedDateRange = tempPickedRange;
                //     });
                //     Navigator.of(context).pop(tempPickedRange);
                //   },
                //   child: Text('Select Date Range'),
                // ),
              ],
            ),
          ),
        );
      },
    );
    // if (picked != null && picked != _selectedDateRange) {
    //   setState(() {
    //     _selectedDateRange = picked;
    //   });
    // }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xffF6F6F6),
      body: Center(
        child: LayoutBuilder(
          builder: (context, constraints) {
            return Column(
              children: [
                _buildTopSection(context, constraints),
                BuildTimeSheetSection()
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildTopSection(BuildContext context, BoxConstraints constraints) {
    double containerHeight = constraints.maxHeight * 0.30;

    return Container(
      height: containerHeight,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildClockCard(context, containerHeight),
          _buildRequestsCard(context, containerHeight),
        ],
      ),
    );
  }

  Widget _buildClockCard(BuildContext context, double height) {
    return Expanded(
      flex: 2,
      child: Padding(
        padding: const EdgeInsets.all(8.0),
        child: Container(
          height: height,
          child: Card(
            color: Colors.white,
            elevation: 4,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildClockHeader(),
                _buildClockButton(context, height),
                _buildTotalWorkHours(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildClockHeader() {
    return Padding(
      padding: const EdgeInsets.all(12.0),
      child: Text(
        "Today's clock",
        style: openSansHebrewTextStyle.copyWith(
          fontWeight: FontWeight.w700,
          color: Colors.black,
          fontSize: 20,
        ),
      ),
    );
  }

  Widget _buildClockButton(BuildContext context, double height) {
    double iconSize = height * 0.1;

    return Expanded(
      child: TextButton(
        style: TextButton.styleFrom(overlayColor: Colors.white),
        onPressed: () {
          _showAddUsersBottomSheet(context);
        },
        child: Align(
          alignment: Alignment.center,
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(8),
              color: Colors.white,
            ),
            padding: const EdgeInsets.all(20),
            child: MouseRegion(
              onEnter: (_) => setState(() => _isHovered = true),
              onExit: (_) => setState(() => _isHovered = false),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                curve: Curves.easeInOut,
                child: Transform.scale(
                  scale: _isHovered ? 1.2 : 1.0,
                  child: Container(
                    width: iconSize * 3.0,
                    height: iconSize * 3.0,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: const LinearGradient(
                        colors: [Colors.blue, Color(0xff31C5DA)],
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.2),
                          spreadRadius: _isHovered ? 4 : 2,
                          blurRadius: _isHovered ? 10 : 5,
                          offset: const Offset(0, 3),
                        ),
                      ],
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.timer_outlined,
                          color: Colors.white,
                          size: iconSize,
                        ),
                        const SizedBox(height: 5),
                        Text(
                          'Clock in',
                          style: openSansHebrewTextStyle.copyWith(
                            color: Colors.white,
                            fontSize: iconSize * 0.4,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTotalWorkHours() {
    return Padding(
      padding: const EdgeInsets.all(12.0),
      child: Card(
        elevation: 2,
        color: const Color(0xffF5F5F5),
        child: Padding(
          padding: const EdgeInsets.all(8.0),
          child: Row(
            children: [
              Text(
                "Total Work hours today:",
                style: openSansHebrewTextStyle.copyWith(
                  fontWeight: FontWeight.w400,
                  color: const Color(0xff3f4648),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 3.0),
                child: Text(
                  "00:00",
                  style: openSansHebrewTextStyle.copyWith(
                    color: Colors.black,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showAddUsersBottomSheet(BuildContext context) {
    showModalBottomSheet(
      constraints: BoxConstraints(),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(20.0),
          topRight: Radius.circular(20.0),
        ),
      ),
      backgroundColor: Colors.transparent,
      context: context,
      isScrollControlled: true,
      builder: (context) {
        return Container(
          height: MediaQuery.of(context).size.height *
              0.9, // Adjust the height as needed
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.only(
              topLeft: Radius.circular(20),
              topRight: Radius.circular(20),
            ),
          ),
          child: AddUsersScreen(),
        );
      },
    );
  }

  Widget _buildRequestsCard(BuildContext context, double height) {
    return Expanded(
      flex: 1,
      child: Container(
        padding: const EdgeInsets.all(8),
        height: height,
        child: Card(
          elevation: 4,
          color: Colors.white,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildRequestsHeader(),
                const Divider(),
                _buildRequestItem(
                  "Add a shift request",
                  const LinearGradient(
                    colors: [Colors.blue, Color(0xff31C5DA)],
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                  ),
                  Icons.add,
                ),
                _buildRequestItem(
                  "Add an absence request",
                  const LinearGradient(
                    colors: [Color(0xff44d9b8), Color(0xff44d9b8)],
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                  ),
                  Icons.light_mode,
                ),
                const Divider(),
                _buildViewRequestsButton(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildRequestsHeader() {
    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: Text(
        "Requests",
        style: openSansHebrewTextStyle.copyWith(
          fontWeight: FontWeight.w700,
          color: Colors.black,
          fontSize: 20,
        ),
      ),
    );
  }

  Widget _buildRequestItem(
    String title,
    LinearGradient gradient,
    IconData icon,
  ) {
    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: Card(
        color: Colors.white,
        elevation: 4,
        child: ListTile(
          leading: Container(
            width: 30,
            height: 30,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: gradient,
            ),
            child: Icon(
              icon,
              color: Colors.white,
              size: 20,
            ),
          ),
          title: Text(
            title,
            style: openSansHebrewTextStyle,
          ),
        ),
      ),
    );
  }

  Widget _buildViewRequestsButton() {
    return Center(
      child: Container(
        padding: const EdgeInsets.all(8.0),
        child: Card(
          color: const Color(0xffEAF5FF),
          child: Padding(
            padding: const EdgeInsets.all(8.0),
            child: Center(
              child: Text(
                "View your requests",
                style: openSansHebrewTextStyle.copyWith(
                  color: Colors.blue,
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTimesheetHeader(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Text(
                "Timesheet",
                style: openSansHebrewTextStyle.copyWith(
                  fontWeight: FontWeight.w700,
                  color: Colors.black,
                  fontSize: 20,
                ),
              ),
              const SizedBox(width: 8),
              Container(
                decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey, width: 0.1),
                    borderRadius: BorderRadius.circular(8)),
                child: TextButton(
                  onPressed: () => _selectDateRange(context),
                  child: Text(
                    _selectedDateRange == null
                        ? "Select Date Range"
                        : "${_selectedDateRange!.startDate.toString().substring(0, 10)}"
                            " - ${_selectedDateRange!.endDate?.toString().substring(0, 10) ?? ''}",
                    style: openSansHebrewTextStyle,
                  ),
                ),
              ),
            ],
          ),
          Row(
            children: [
              ExportWidget(onExport: () {}),
              const SizedBox(width: 8),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTimesheetTable(BuildContext context) {
    return Expanded(
      child: SingleChildScrollView(
        child: DataTable(
          columns: const [
            DataColumn(label: Text("Date")),
            DataColumn(label: Text("Type")),
            DataColumn(label: Text("Sub job")),
            DataColumn(label: Text("Start")),
            DataColumn(label: Text("End")),
            DataColumn(label: Text("Total hours")),
            DataColumn(label: Text("Daily total")),
            DataColumn(label: Text("Weekly total")),
            DataColumn(label: Text("Total regular")),
          ],
          rows: _generateRows(),
        ),
      ),
    );
  }

  List<DataRow> _generateRows() {
    return [
      const DataRow(cells: [
        DataCell(Text("Tue 8/6")),
        DataCell(Text("--")),
        DataCell(Text("--")),
        DataCell(Text("--")),
        DataCell(Text("--")),
        DataCell(Text("--")),
        DataCell(Text("--")),
        DataCell(Text("--")),
        DataCell(Text("--")),
      ]),
      DataRow(cells: [
        const DataCell(Text("Mon 8/5")),
        const DataCell(Text("Front Desk")),
        const DataCell(Text("--")),
        const DataCell(Text("07:02 PM")),
        const DataCell(Text("07:02 PM")),
        const DataCell(Text("--")),
        const DataCell(Text("--")),
        const DataCell(Text("--")),
        DataCell(IconButton(
          icon: const Icon(Icons.delete),
          onPressed: () {},
        )),
      ]),
      // Add more rows as needed
    ];
  }

  void _onSelectionChanged(
      DateRangePickerSelectionChangedArgs dateRangePickerSelectionChangedArgs) {
    final PickerDateRange range = dateRangePickerSelectionChangedArgs.value;
    setState(() {
      _selectedDateRange = range;
    });
  }
}

class BuildTimeSheetSection extends StatefulWidget {
  const BuildTimeSheetSection({super.key});

  @override
  State<BuildTimeSheetSection> createState() => _BuildTimeSheetSectionState();
}

class _BuildTimeSheetSectionState extends State<BuildTimeSheetSection> {
  List<Employee> _allEmployees = [];
  EmployeeDataSource? _employeeDataSource;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance.collection('users').snapshots(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snapshot.hasError) {
              return Center(child: Text('Error: ${snapshot.error}'));
            }

            if (snapshot.hasData) {
              _allEmployees =
                  EmployeeDataSource.mapSnapshotToEmployeeList(snapshot.data!);
            }

            return Padding(
              padding: const EdgeInsets.all(8.0),
              child: Container(
                color: Colors.white,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // _buildTimesheetHeader(context),
                    Expanded(
                      child: SfDataGridTheme(
                        data: const SfDataGridThemeData(
                          headerColor: Color(0xffF8F8F8),
                        ),
                        child: SingleChildScrollView(
                          physics: const ScrollPhysics(),
                          scrollDirection: Axis.horizontal,
                          child: Container(
                            width:
                                1500, // Set a fixed width to enable horizontal scrolling
                            child: SfDataGrid(
                              source: _employeeDataSource!,
                              columnWidthMode: ColumnWidthMode.fill,
                              columns: <GridColumn>[
                                GridColumn(
                                  columnName: 'FirstName',
                                  label: Container(
                                    padding: const EdgeInsets.all(8.0),
                                    alignment: Alignment.center,
                                    child: Text(
                                      'First Name',
                                      style: openSansHebrewTextStyle.copyWith(
                                          color: const Color(0xff3f4648),
                                          fontWeight: FontWeight.w500),
                                    ),
                                  ),
                                ),
                                GridColumn(
                                  columnName: 'LastName',
                                  label: Container(
                                    padding: const EdgeInsets.all(8.0),
                                    alignment: Alignment.center,
                                    child: const Text(
                                      'Last Name',
                                      style: TextStyle(
                                          fontWeight: FontWeight.bold),
                                    ),
                                  ),
                                ),
                                GridColumn(
                                  columnName: 'Email',
                                  label: Container(
                                    padding: const EdgeInsets.all(8.0),
                                    alignment: Alignment.center,
                                    child: const Text(
                                      'Email',
                                      style: TextStyle(
                                          fontWeight: FontWeight.bold),
                                    ),
                                  ),
                                ),
                                GridColumn(
                                  columnName: 'CountryCode',
                                  label: Container(
                                    padding: const EdgeInsets.all(8.0),
                                    alignment: Alignment.center,
                                    child: const Text(
                                      'Country Code',
                                      style: TextStyle(
                                          fontWeight: FontWeight.bold),
                                    ),
                                  ),
                                ),
                                GridColumn(
                                  columnName: 'MobilePhone',
                                  label: Container(
                                    padding: const EdgeInsets.all(8.0),
                                    alignment: Alignment.center,
                                    child: const Text(
                                      'Mobile Phone',
                                      style: TextStyle(
                                          fontWeight: FontWeight.bold),
                                    ),
                                  ),
                                ),
                                GridColumn(
                                  columnName: 'UserType',
                                  label: Container(
                                    padding: const EdgeInsets.all(8.0),
                                    alignment: Alignment.center,
                                    child: const Text(
                                      'User Type',
                                      style: TextStyle(
                                          fontWeight: FontWeight.bold),
                                    ),
                                  ),
                                ),
                                GridColumn(
                                  columnName: 'Title',
                                  label: Container(
                                    padding: const EdgeInsets.all(8.0),
                                    alignment: Alignment.center,
                                    child: const Text(
                                      'Title',
                                      style: TextStyle(
                                          fontWeight: FontWeight.bold),
                                    ),
                                  ),
                                ),
                                GridColumn(
                                  columnName: 'EmploymentStartDate',
                                  label: Container(
                                    padding: const EdgeInsets.all(8.0),
                                    alignment: Alignment.center,
                                    child: const Text(
                                      'Employment Start Date',
                                      style: TextStyle(
                                          fontWeight: FontWeight.bold),
                                    ),
                                  ),
                                ),
                                GridColumn(
                                  columnName: 'KioskCode',
                                  label: Container(
                                    padding: const EdgeInsets.all(8.0),
                                    alignment: Alignment.center,
                                    child: const Text(
                                      'Kiosk Code',
                                      style: TextStyle(
                                          fontWeight: FontWeight.bold),
                                    ),
                                  ),
                                ),
                                GridColumn(
                                  columnName: 'DateAdded',
                                  label: Container(
                                    padding: const EdgeInsets.all(8.0),
                                    alignment: Alignment.center,
                                    child: const Text(
                                      'Date Added',
                                      style: TextStyle(
                                          fontWeight: FontWeight.bold),
                                    ),
                                  ),
                                ),
                                GridColumn(
                                  columnName: 'LastLogin',
                                  label: Container(
                                    padding: const EdgeInsets.all(8.0),
                                    alignment: Alignment.center,
                                    child: const Text(
                                      'Last Login',
                                      style: TextStyle(
                                          fontWeight: FontWeight.bold),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    )
                  ],
                ),
              ),
            );
          }),
    );

    ;
  }

  @override
  void initState() {
    _employeeDataSource = EmployeeDataSource(employees: []);
  }
}

//
// class BuildTimesheetSection extends StatelessWidget {
//
//   return
