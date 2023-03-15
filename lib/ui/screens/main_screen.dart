import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:fireout/cubit/bottom_nav_cubit.dart';
// import 'package:fireout/ui/screens/dashboard/dashboard_screen.dart';
// import 'package:fireout/ui/screens/profile/profile_screen.dart';
import 'package:fireout/ui/widgets/bottom_bar_item.dart';

class MainScreen extends StatefulWidget {
  const MainScreen({Key? key}) : super(key: key);

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  @override
  void initState() {
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    List<Widget> pages = [];
    return BlocBuilder<BottomNavCubit, int>(
      builder: (context, state) {
        return Scaffold(
          backgroundColor: Theme.of(context).primaryColor,
          body: AnimatedSwitcher(
              duration: const Duration(milliseconds: 200), child: pages[state]),
          bottomNavigationBar: Container(
            height: 65,
            color: Theme.of(context).primaryColorLight,
            padding: const EdgeInsets.all(10),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                BottomBarItem(
                  assetImage: 'assets/icons/home.png',
                  isSelected: state == 0,
                  label: 'Home',
                  onTap: () => context.read<BottomNavCubit>().updateIndex(0),
                ),
                BottomBarItem(
                  assetImage: 'assets/icons/profile.png',
                  isSelected: state == 3,
                  label: 'Profile',
                  onTap: () => context.read<BottomNavCubit>().updateIndex(3),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
