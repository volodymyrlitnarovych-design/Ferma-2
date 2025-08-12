
import 'dart:convert';
import 'dart:math';
import 'package:flame/components.dart';
import 'package:flame/events.dart';
import 'package:flame/game.dart';
import 'package:flame/input.dart';
import 'package:flutter/material.dart';
import 'package:flame_audio/flame_audio.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'save.dart';
import 'settings.dart';
import 'tutorial.dart';
import 'menu.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(GameWidget(
    game: OpenFarmGame(),
    overlayBuilderMap: {
      ShopOverlay.id: (context, game) => ShopOverlay(game: game as OpenFarmGame),
      SettingsOverlay.id: (context, game) => SettingsOverlay(
        game: game,
        onResume: () => (game as OpenFarmGame).closeSettings(),
        onSave: () => (game as OpenFarmGame).saveProgress(),
        onLoad: () => (game as OpenFarmGame).loadProgress(),
        onReset: () => (game as OpenFarmGame).resetProgress(),
      ),
      TutorialOverlay.id: (context, game) => TutorialOverlay(onClose: () => (game as OpenFarmGame).closeTutorial()),
      MainMenuOverlay.id: (context, game) {
        final g = game as OpenFarmGame;
        return MainMenuOverlay(
          language: g.language, characterColor: g.characterColor, dayLength: g.dayLength,
          onPlay: g.startGameFromMenu, onLanguage: g.setLanguage, onCharacterColor: g.setCharacterColor, onDayLength: g.setDayLength,
        );
      },
    },
  ));
}

enum Crop { wheat, sunflower, barley, pea, beet, rapeseed }
Crop cropFromKey(String k){ switch(k){ case 'sunflower': return Crop.sunflower; case 'barley': return Crop.barley; case 'pea': return Crop.pea; case 'beet': return Crop.beet; case 'rapeseed': return Crop.rapeseed; default: return Crop.wheat; } }
String cropKey(Crop c){ switch(c){ case Crop.sunflower: return 'sunflower'; case Crop.barley: return 'barley'; case Crop.pea: return 'pea'; case Crop.beet: return 'beet'; case Crop.rapeseed: return 'rapeseed'; case Crop.wheat: default: return 'wheat'; } }

class OpenFarmGame extends FlameGame with HasTappables, HasDraggables, HasCollisionDetection {
  late final CameraComponent cam;
  late final FarmWorld world;
  late final JoystickComponent joystick;
  late final Hud hud;
  late final MiniMap miniMap;
  late final Speedometer speedo;

  Vehicle activeVehicle = VehicleType.tractor.create(brand:"John Deere", model:"7810", speed:260, fuelRate:0.08);
  List<Vehicle> garage = [];
  String language = 'uk';
  String characterColor = 'green';
  double dayLength = 120.0;
  bool musicOn = true;

  bool get shopOpen => overlays.isActive(ShopOverlay.id);
  bool get onMenu => overlays.isActive(MainMenuOverlay.id);

  @override
  Future<void> onLoad() async {
    await super.onLoad();
    await FlameAudio.audioCache.loadAll(['sfx/engine_idle.wav','sfx/engine_run.wav','sfx/harvest.wav','sfx/plow.wav','sfx/seed.wav','sfx/buy.wav','sfx/click.wav',
      'music/theme_chill.wav','music/theme_upbeat.wav','music/theme_night.wav']);
    camera.viewport = FixedResolutionViewport(Vector2(1080, 1920));

    world = FarmWorld(seed: 77, dayLength: dayLength)..position = Vector2.zero(); add(world);
    cam = CameraComponent(world: world)..viewfinder.anchor = Anchor.center..priority = 1; add(cam);
    activeVehicle.position = Vector2(500, 500); world.add(activeVehicle); cam.follow(activeVehicle);

    joystick = JoystickComponent(
      knob: CircleComponent(radius: 35),
      background: CircleComponent(radius: 90, paint: Paint()..style = PaintingStyle.stroke..strokeWidth=3),
      margin: const EdgeInsets.only(left: 30, bottom: 30),
    )..priority = 1000; add(joystick);

    hud = Hud(game: this)..priority = 1100; add(hud);
    miniMap = MiniMap(world: world)..priority = 1101; add(miniMap);
    speedo = Speedometer(game: this)..priority = 1102; add(speedo);

    // load catalogs
    world.catalog = (json.decode(await rootBundle.loadString('assets/vehicle_catalog.json')) as List).cast<Map<String,dynamic>>();
    world.implementsCatalog = (json.decode(await rootBundle.loadString('assets/implements.json')) as List).cast<Map<String,dynamic>>();
    world.cropsInfo = { for (final m in (json.decode(await rootBundle.loadString('assets/crops.json')) as List)) m['key']: m };

    // show menu first
    overlays.add(MainMenuOverlay.id);
    if (musicOn) FlameAudio.loop('music/theme_chill.wav', volume:.35);
  }

  void startGameFromMenu() { overlays.remove(MainMenuOverlay.id); overlays.add(TutorialOverlay.id); }
  void setLanguage(String? l){ if(l!=null) language = l; }
  void setCharacterColor(String? c){ if(c!=null) characterColor = c; }
  void setDayLength(double v){ dayLength = v; world.dayLength = v; }

  @override
  void update(double dt) {
    super.update(dt);
    if (!shopOpen && !onMenu) activeVehicle.handleJoystick(joystick, dt, world);
    world.updateDayNight(dt);
    speedo.currentSpeed = activeVehicle.lastSpeed;
  }

  void switchVehicle(Vehicle v) { final oldPos = activeVehicle.position.clone(); activeVehicle.removeFromParent(); activeVehicle = v..position = oldPos; world.add(activeVehicle); cam.follow(activeVehicle); }
  void toggleShop() => shopOpen ? overlays.remove(ShopOverlay.id) : overlays.add(ShopOverlay.id);
  void openSettings() => overlays.add(SettingsOverlay.id); void closeSettings() => overlays.remove(SettingsOverlay.id); void closeTutorial() => overlays.remove(TutorialOverlay.id);

  // Save/Load
  Future<void> saveProgress() async {
    await SaveSystem.save(SaveData(
      money: world.money, fuel: world.fuel, cropStore: world.cropsStore, seeds: world.seedsByCrop,
      characterColor: characterColor, language: language, dayLength: world.dayLength
    ));
  }
  Future<void> loadProgress() async {
    final d = await SaveSystem.load(); if (d==null) return;
    world.money = d.money; world.fuel = d.fuel; world.cropsStore = d.cropStore; world.seedsByCrop = d.seeds; characterColor = d.characterColor; language = d.language; world.dayLength = d.dayLength;
  }
  Future<void> resetProgress() async { await SaveSystem.reset(); }
}

// ----- World -----
enum TileState { soil, plowed, cultivated, seeded, growing, mature, road, water }
class FarmWorld extends World with HasGameRef<OpenFarmGame> {
  final int width; final int height; final int tile; final int seed; double dayLength;
  late List<TileState> tiles; late List<String?> cropType; // crop key for seeded/growing/mature
  double timeOfDay = 0;
  // economy & storage
  int money = 20000; double fuel = 100.0; double maxFuel = 150.0;
  Map<String,int> cropsStore = {}; Map<String,int> seedsByCrop = {'wheat':100,'sunflower':40,'barley':80,'pea':40,'beet':20,'rapeseed':40};
  List<Map<String,dynamic>> catalog = []; List<Map<String,dynamic>> implementsCatalog = []; Map<String,dynamic> cropsInfo = {};
  Crop selectedCrop = Crop.wheat;

  FarmWorld({this.width=220, this.height=220, this.tile=32, this.seed=1, required this.dayLength});
  final Random _rng = Random();

  @override Future<void> onLoad() async {
    tiles = List.generate(width*height, (_)=>TileState.soil);
    cropType = List.generate(width*height, (_)=>null);
    for (int x=0;x<width;x++){ tiles[_idx(x, height~/2)] = TileState.road; if (x%17==0) tiles[_idx(x,(height~/2)-1)] = TileState.road; }
    for (int y=30;y<60;y++){ tiles[_idx(20,y)] = TileState.water; tiles[_idx(21,y)] = TileState.water; }
    for (int i=0;i<2600;i++){ int x=_rng.nextInt(width), y=_rng.nextInt(height); if(tiles[_idx(x,y)]==TileState.soil){ tiles[_idx(x,y)]=TileState.mature; cropType[_idx(x,y)]='wheat'; } }
    add(WorldRenderer(this));
  }

  int _idx(int x,int y)=>y*width+x;
  TileState getTile(int x,int y){ if(x<0||y<0||x>=width||y>=height) return TileState.water; return tiles[_idx(x,y)]; }
  String? getCropKey(int x,int y)=> cropType[_idx(x,y)];
  void setTile(int x,int y,TileState s,{String? crop}){ if(x<0||y<0||x>=width||y>=height) return; tiles[_idx(x,y)] = s; if(crop!=null) cropType[_idx(x,y)] = crop; }
  void updateDayNight(double dt){ timeOfDay = (timeOfDay + dt/dayLength) % 1.0; }

  bool plowAt(Vector2 pos, double eff){ var t=_toTile(pos); if(getTile(t.x,t.y)==TileState.soil){ setTile(t.x,t.y,TileState.plowed); FlameAudio.play('sfx/plow.wav', volume:.4); return true;} return false; }
  bool cultivateAt(Vector2 pos, double eff){ var t=_toTile(pos); if(getTile(t.x,t.y)==TileState.plowed){ setTile(t.x,t.y,TileState.cultivated); return true;} return false; }
  bool seedAt(Vector2 pos, String crop, double rate){
    var t=_toTile(pos);
    if (seedsByCrop[crop]==null || seedsByCrop[crop]!.toDouble() <= 0) return false;
    if (getTile(t.x,t.y)==TileState.cultivated) { setTile(t.x,t.y,TileState.seeded, crop: crop); seedsByCrop[crop] = (seedsByCrop[crop]??0) - 1; FlameAudio.play('sfx/seed.wav', volume:.4); return true; }
    return false;
  }
  bool harvestAt(Vector2 pos, String? crop){
    var t=_toTile(pos);
    if (getTile(t.x,t.y)==TileState.mature && cropType[_idx(t.x,t.y)]!=null){
      final key = cropType[_idx(t.x,t.y)]!;
      setTile(t.x,t.y,TileState.soil, crop: null); cropsStore[key] = (cropsStore[key]??0) + (cropsInfo[key]?['yield']??1) as int;
      FlameAudio.play('sfx/harvest.wav', volume:.5); return true;
    }
    return false;
  }
  void tickGrowth(double dt){
    if(_rng.nextDouble()<0.01){
      for(int i=0;i<70;i++){
        final x=_rng.nextInt(width), y=_rng.nextInt(height); final st=getTile(x,y);
        if(st==TileState.seeded) setTile(x,y,TileState.growing, crop: cropType[_idx(x,y)]);
        else if(st==TileState.growing) setTile(x,y,TileState.mature, crop: cropType[_idx(x,y)]);
      }
    }
  }

  Point<int> _toTile(Vector2 pos)=> Point((pos.x~/tile),(pos.y~/tile));

  // Economy
  void sellCrop(String key, int amount){
    final sell = amount.clamp(0, cropsStore[key]??0);
    cropsStore[key] = (cropsStore[key]??0) - sell;
    money += sell * (cropsInfo[key]?['sell_price']??4) as int;
  }
  bool buySeeds(String key, int amount){
    final price = (cropsInfo[key]?['seed_cost']??2) as int;
    final cost = amount * price; if(money>=cost){ money-=cost; seedsByCrop[key] = (seedsByCrop[key]??0) + amount; FlameAudio.play('sfx/buy.wav', volume:.5); return true;} return false;
  }
  bool buyFuel(double liters,{double pricePerLiter=1.2}){ final cost=(liters*pricePerLiter).round(); if(money>=cost && fuel+liters<=maxFuel+1e-6){ money-=cost; fuel+=liters; FlameAudio.play('sfx/buy.wav', volume:.5); return true;} return false; }
}

class WorldRenderer extends PositionComponent with HasGameRef<OpenFarmGame> {
  final FarmWorld world; WorldRenderer(this.world);
  @override Future<void> onLoad() async { size = Vector2(world.width*world.tile.toDouble(), world.height*world.tile.toDouble()); }
  @override void render(Canvas canvas){
    final t=world.tile.toDouble(); final paint=Paint(); final b=0.55 + 0.45 * sin(world.timeOfDay * pi * 2);
    for(int y=0;y<world.height;y++){ for(int x=0;x<world.width;x++){ final st=world.tiles[y*world.width+x]; Color c;
      switch(st){
        case TileState.soil: c=const Color(0xFF6B4F2E); break; case TileState.plowed: c=const Color(0xFF4A331B); break;
        case TileState.cultivated: c=const Color(0xFF5B3A1F); break; case TileState.seeded: c=const Color(0xFF3E6B2E); break;
        case TileState.growing: c=const Color(0xFF4FAA3B); break; case TileState.mature: c=const Color(0xFFE5C158); break;
        case TileState.road: c=const Color(0xFF3D3D3D); break; case TileState.water: c=const Color(0xFF2D6CDF); break;
      }
      paint.color = c.withOpacity(b); canvas.drawRect(Rect.fromLTWH(x*t, y*t, t, t), paint);
    }}
  }
}

// Vehicles & implements
enum VehicleType { tractor, seeder, harvester }
enum ImplementType { none, plow, cultivator, seeder }

abstract class Vehicle extends PositionComponent with HasGameRef<OpenFarmGame> {
  final VehicleType type; final String brand; final String model; double speed; double fuelRate; double idleFuelRate=0.01; double trackTimer=0;
  ImplementType implement = ImplementType.none;
  double implementEff = 1.0; double seedRate = 1.0;
  double lastSpeed = 0;
  String? cropForHarvester;

  Vehicle(this.type,{required this.brand, required this.model, required this.speed, required this.fuelRate, this.cropForHarvester});

  @override Future<void> onLoad() async { size = Vector2(64,64); anchor = Anchor.center; FlameAudio.loop('sfx/engine_idle.wav', volume:.2); }

  @override void render(Canvas c){
    final p=Paint()..style=PaintingStyle.fill; switch(type){ case VehicleType.tractor: p.color=_color(gameRef.characterColor); break; case VehicleType.seeder: p.color=const Color(0xFF3498DB); break; case VehicleType.harvester: p.color=const Color(0xFFE74C3C); break; }
    final r=Rect.fromLTWH(0,0,size.x,size.y); c.drawRRect(RRect.fromRectAndRadius(r,const Radius.circular(12)),p); p.color=Colors.black; c.drawCircle(Offset(12,size.y-8),8,p); c.drawCircle(Offset(size.x-12,size.y-8),8,p);
    // simple draw implement bar
    if (implement != ImplementType.none){ p.color=Colors.white24; c.drawRect(Rect.fromLTWH(-6, size.y/2-4, 12, 8), p); }
  }

  Color _color(String name){ switch(name){ case 'blue': return const Color(0xFF2E86DE); case 'red': return const Color(0xFFEB4D4B); default: return const Color(0xFF2ECC71);} }

  void handleJoystick(JoystickComponent js,double dt,FarmWorld w){
    final dir=js.relativeDelta;
    if(dir.isZero()){ w.fuel=max(0, w.fuel - idleFuelRate*dt); lastSpeed = 0; return; }
    if(w.fuel<=0){ lastSpeed = 0; return; }
    final next=position + dir*speed*dt; final tile=w.getTile((next.x~/w.tile),(next.y~/w.tile)); if(tile==TileState.water){ lastSpeed = 0; return; }
    lastSpeed = (dir.length * speed);
    position=next; w.fuel=max(0, w.fuel - fuelRate*dt * (1.0 + (implement==ImplementType.none?0:0.2)));
    trackTimer+=dt; if(trackTimer>0.2){ trackTimer=0; w.add(TireTrack(position.clone(), size)); }

    // work logic
    if(type==VehicleType.tractor){
      if(implement==ImplementType.plow) w.plowAt(position, implementEff);
      else if(implement==ImplementType.cultivator) w.cultivateAt(position, implementEff);
      else if(implement==ImplementType.seeder) w.seedAt(position, cropKey(w.selectedCrop), seedRate);
      w.tickGrowth(dt);
    } else if(type==VehicleType.harvester){
      w.harvestAt(position, cropForHarvester);
      w.tickGrowth(dt);
    }
  }
}

class Tractor extends Vehicle{ Tractor({required super.brand, required super.model, required super.speed, required super.fuelRate}) : super(VehicleType.tractor); }
class SeederV extends Vehicle{ SeederV({required super.brand, required super.model, required super.speed, required super.fuelRate}) : super(VehicleType.seeder); }
class Harvester extends Vehicle{ Harvester({required super.brand, required super.model, required super.speed, required super.fuelRate, required String crop}) : super(VehicleType.harvester, cropForHarvester: crop); }

extension VehicleFactory on VehicleType{
  Vehicle create({required String brand, required String model, required double speed, required double fuelRate, String? crop}){
    switch(this){ case VehicleType.tractor: return Tractor(brand:brand, model:model, speed:speed, fuelRate:fuelRate);
      case VehicleType.seeder: return SeederV(brand:brand, model:model, speed:speed, fuelRate:fuelRate);
      case VehicleType.harvester: return Harvester(brand:brand, model:model, speed:speed, fuelRate:fuelRate, crop: crop??'wheat'); }
  }
}

class TireTrack extends PositionComponent{ double life=2.5; TireTrack(Vector2 pos, Vector2 size){ position = pos - Vector2(size.x/2, size.y/2) + Vector2(0, size.y/2 - 8); }
  @override void render(Canvas c){ final a=(life/2.5).clamp(0.0,1.0); final p=Paint()..color=Colors.black.withOpacity(0.15*a); c.drawRRect(RRect.fromRectAndRadius(Rect.fromLTWH(0,0,40,6), const Radius.circular(3)), p); }
  @override void update(double dt){ life-=dt; if(life<=0) removeFromParent(); }}

// HUD / UI
class Hud extends PositionComponent with HasGameRef<OpenFarmGame>, Tappable {
  final OpenFarmGame game;
  Hud({required this.game});

  @override Future<void> onLoad() async {
    size = game.camera.viewport.size; position = Vector2.zero();
    add(_button("Трактор", Vector2(20, 20), (){ final t = game.garage.where((v)=>v is Tractor).cast<Vehicle>().firstOrNull ?? game.activeVehicle; game.switchVehicle(t);}));
    add(_button("Комбайн", Vector2(160, 20), (){ final t = game.garage.where((v)=>v is Harvester).cast<Vehicle>().firstOrNull ?? game.activeVehicle; game.switchVehicle(t);}));
    add(_button("Магазин", Vector2(300, 20), () => game.toggleShop()));
    add(_button("Пауза", Vector2(440, 20), () => game.openSettings()));
    add(_button("Культура", Vector2(580, 20), () { // cycle crop
      final values = Crop.values; final idx = values.indexOf(game.world.selectedCrop); game.world.selectedCrop = values[(idx+1)%values.length];
    }));
    add(StatsLabel(game: game)..position = Vector2(size.x - 20, 20));
  }

  ButtonComponent _button(String text, Vector2 pos, void Function() onTap){
    return ButtonComponent(
      button: RectangleComponent(size: Vector2(120, 56), paint: Paint()..color = const Color(0xAA222222)),
      anchor: Anchor.topLeft, position: pos,
      children: [TextComponent(text: text, anchor: Anchor.center, position: Vector2(60, 28), textRenderer: TextPaint(style: const TextStyle(color: Colors.white, fontSize: 16)))],
      onPressed: onTap, priority: 1200,
    );
  }
}

class StatsLabel extends TextComponent with HasGameRef<OpenFarmGame>{
  final OpenFarmGame game; StatsLabel({required this.game}) : super(text:"", textRenderer: TextPaint(style: const TextStyle(color: Colors.white, fontSize: 16)));
  @override void update(double dt){ super.update(dt);
    position = Vector2(game.camera.viewport.size.x - 20, 20); anchor = Anchor.topRight;
    final fuel = game.world.fuel.toStringAsFixed(1); final money = game.world.money;
    final tod = (game.world.timeOfDay*24).toStringAsFixed(1); final crop = cropKey(game.world.selectedCrop);
    text = "₴$money | Паливо: $fuel л | Культура: $crop | Час: $tod";
  }
}

class MiniMap extends PositionComponent with HasGameRef<OpenFarmGame>{
  final FarmWorld world; MiniMap({required this.world});
  @override Future<void> onLoad() async { size = Vector2(260, 260); position = Vector2(gameRef.camera.viewport.size.x - size.x - 20, gameRef.camera.viewport.size.y - size.y - 20); }
  @override void render(Canvas c){
    final paint = Paint()..color = const Color(0x99000000);
    c.drawRRect(RRect.fromRectAndRadius(Rect.fromLTWH(0,0,size.x,size.y), const Radius.circular(12)), paint);
    final scaleX = size.x / (world.width*1.0); final scaleY = size.y / (world.height*1.0);
    final p = Paint();
    for(int y=0;y<world.height;y+=4){
      for(int x=0;x<world.width;x+=4){
        final st = world.tiles[y*world.width+x]; Color col;
        switch(st){ case TileState.water: col=const Color(0xFF2D6CDF); break; case TileState.road: col=const Color(0xFFAAAAAA); break; case TileState.mature: col=const Color(0xFFE5C158); break; default: col=const Color(0xFF4E6B3A); }
        p.color = col;
        c.drawRect(Rect.fromLTWH(x*scaleX, y*scaleY, 3, 3), p);
      }
    }
    // player marker
    final v = gameRef.activeVehicle.position; final mx = v.x/world.tile*scaleX, my=v.y/world.tile*scaleY;
    p.color = const Color(0xFFFFFFFF); c.drawCircle(Offset(mx,my), 3, p);
  }
}

class Speedometer extends PositionComponent with HasGameRef<OpenFarmGame>{
  final OpenFarmGame game; double currentSpeed=0; Speedometer({required this.game});
  @override Future<void> onLoad() async { size = Vector2(220, 90); position = Vector2(20, game.camera.viewport.size.y - size.y - 20); }
  @override void render(Canvas c){
    final bg = Paint()..color = const Color(0xAA111111); c.drawRRect(RRect.fromRectAndRadius(Rect.fromLTWH(0,0,size.x,size.y), const Radius.circular(12)), bg);
    final tp = TextPaint(style: const TextStyle(color: Colors.white)); tp.render(c, "Швидкість: ${currentSpeed.toStringAsFixed(0)}", Vector2(12, 12));
    tp.render(c, "Паливо: ${game.world.fuel.toStringAsFixed(1)} л", Vector2(12, 34));
    final sel = cropKey(game.world.selectedCrop); tp.render(c, "Насіння(${sel}): ${game.world.seedsByCrop[sel]??0}", Vector2(12, 56));
  }
}

// Shop with implements & vehicles & seeds
class ShopOverlay extends StatelessWidget{
  static const id='shop'; final OpenFarmGame game; const ShopOverlay({super.key, required this.game});
  @override Widget build(BuildContext context){
    final w = game.world;
    return Align(alignment:Alignment.topCenter,child:Container(
      margin:const EdgeInsets.only(top:100),padding:const EdgeInsets.all(12),width:1040,
      decoration:BoxDecoration(color:const Color(0xDD111111),borderRadius:BorderRadius.circular(16)),
      child:DefaultTextStyle(style:const TextStyle(color:Colors.white),child:Column(mainAxisSize:MainAxisSize.min,children:[
        Row(mainAxisAlignment:MainAxisAlignment.spaceBetween,children:[const Text("Магазин",style:TextStyle(fontSize:22,fontWeight:FontWeight.bold)),TextButton(onPressed:()=>game.toggleShop(), child: const Text("Закрити"))]),
        const SizedBox(height:8),
        Row(crossAxisAlignment:CrossAxisAlignment.start,children:[
          Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
            const Text("Ресурси",style:TextStyle(fontSize:18,fontWeight:FontWeight.bold)),const SizedBox(height:6),
            Row(children:[Text("Паливо +20л (₴24)  Поточне: ${w.fuel.toStringAsFixed(1)} / ${w.maxFuel.toStringAsFixed(0)}"), const SizedBox(width:8),
              ElevatedButton(onPressed:(){ w.buyFuel(20);}, child: const Text("Купити"))]),
            const SizedBox(height:6),
            const Text("Насіння (за культурою)"),
            Wrap(spacing:8, runSpacing:8, children:[
              for(final k in w.cropsInfo.keys)
                ElevatedButton(onPressed:(){ w.buySeeds(k, 50); }, child: Text("$k +50")),
            ]),
            const SizedBox(height:10),
            const Text("Продаж урожаю:"),
            Wrap(spacing:8, runSpacing:8, children:[
              for(final k in w.cropsInfo.keys)
                ElevatedButton(onPressed:(){ w.sellCrop(k, 100); }, child: Text("$k -100")),
            ]),
          ])),
          const SizedBox(width:12),
          Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
            const Text("Агрегати",style:TextStyle(fontSize:18,fontWeight:FontWeight.bold)),const SizedBox(height:6),
            SizedBox(height:220, child: ListView.builder(itemCount:w.implementsCatalog.length,itemBuilder:(c,i){
              final it=w.implementsCatalog[i];
              return ListTile(
                title: Text("${it['name']} (${it['type']})  ₴${it['price']}"),
                trailing: ElevatedButton(onPressed:(){
                  // attach to current tractor
                  final v = game.activeVehicle;
                  if (v is Tractor && w.money >= (it['price'] as int)){
                    w.money -= it['price'] as int;
                    v.implement = _implFromStr(it['type']); v.implementEff = (it['efficiency']??1.0).toDouble(); v.seedRate = (it['seed_rate']??1.0).toDouble();
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Куплено і встановлено: ${it['name']}")));
                  } else {
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Потрібен трактор і достатньо коштів")));
                  }
                }, child: const Text("Купити+Встановити")),
              );
            }))
          ])),
          const SizedBox(width:12),
          Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
            const Text("Техніка",style:TextStyle(fontSize:18,fontWeight:FontWeight.bold)),const SizedBox(height:6),
            SizedBox(height:220, child: ListView.builder(itemCount:w.catalog.length,itemBuilder:(c,i){
              final it=w.catalog[i]; final type=it['type'] as String; final price=it['price'] as int;
              return ListTile(
                title: Text("${it['brand']} ${it['model']} ($type) ₴$price"),
                subtitle: Text("Швидк.: ${it['speed']} Паливо/с: ${it['fuel_rate']}"),
                trailing: ElevatedButton(onPressed:(){
                  if (w.money >= price){
                    w.money -= price;
                    final vt = _typeFromString(type);
                    final v = vt.create(brand: it['brand'], model: it['model'], speed: (it['speed'] as num).toDouble(), fuelRate: (it['fuel_rate'] as num).toDouble(), crop: it['crop']);
                    v.position = game.activeVehicle.position.clone();
                    game.garage.add(v);
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Куплено: ${it['brand']} ${it['model']}")));
                  } else {
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Недостатньо коштів")));
                  }
                }, child: const Text("Купити")),
              );
            }))
          ])),
        ]),
        const SizedBox(height:6),
        Row(mainAxisAlignment:MainAxisAlignment.spaceBetween,children:[ Text("Баланс: ₴${w.money}"), Text("Склади: ${w.cropsStore.toString()}") ]),
      ])),
    ));
  }

  ImplementType _implFromStr(String t){ switch(t){ case 'plow': return ImplementType.plow; case 'cultivator': return ImplementType.cultivator; case 'seeder': return ImplementType.seeder; default: return ImplementType.none; } }
  VehicleType _typeFromString(String s){ switch(s){ case 'tractor': return VehicleType.tractor; case 'harvester': return VehicleType.harvester; case 'seeder': return VehicleType.seeder; default: return VehicleType.tractor; } }
}

extension FirstOrNull<E> on Iterable<E>{ E? get firstOrNull => isEmpty ? null : first; }
