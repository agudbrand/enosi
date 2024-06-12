/*
 *  Playing around with event based stuff.
 *
 *  A lot of evil stuff is done in here to try and make C++ do what I want.
 *
 */

#include "iro/platform.h"
#include "iro/containers/pool.h"
#include "iro/containers/list.h"
#include "iro/memory/bump.h"

#include "stdlib.h"

#undef stdout

#define DEFINE_GDB_PY_SCRIPT(script_name) \
  asm("\
.pushsection \".debug_gdb_scripts\", \"MS\",@progbits,1\n\
.byte 1 /* Python */\n\
.asciz \"" script_name "\"\n\
.popsection \n\
");

DEFINE_GDB_PY_SCRIPT("lpp-gdb.py");

using namespace iro;

struct vec2
{
	s32 x,y;

	bool operator==(const vec2& rhs) const { return x == rhs.x && y == rhs.y; }
};

struct KeyPressedEvent
{
	u8 key;
};

struct Player;
struct Animal;

struct PlayerTryMoveEvent
{
	Player* player;
	vec2 destination;
	b8 cancel;
};

struct PlayerMovedEvent
{
	Player* player;
};

struct PlayerAttackEvent
{
	Player* player;
	vec2 attack_pos;
};

struct AnimalDamagedEvent
{
	Animal* animal;
};

struct AnimalDeathEvent
{
	Animal* animal;
};

struct AfterEventProcessingEvent
{};

struct EventBus
{
	// for evil purposes
	struct SubListBase { virtual void init() = 0; };

	u32 raise_nesting = 0;
	b8 processing_post = false;

	template<typename E>
	struct SubList : SubListBase
	{
		struct Subscription
		{
			void* subscriber;
			void (*handler)(void*, E&);
		};

		Pool<Subscription> subscription_pool;
		SList<Subscription> subscriptions;

		void init() override
		{
			subscription_pool = Pool<Subscription>::create();
			subscriptions = SList<Subscription>::create();
		};

		void sub(void* subscriber, void (*f)(void*, E&))
		{
			Subscription* sub = subscription_pool.add();
			sub->subscriber = subscriber;
			sub->handler = f;
			subscriptions.push(sub);
		}

		void emit(EventBus* bus, E& e)
		{
			bus->raise_nesting += 1;
			for (Subscription& s : subscriptions)
			{
				s.handler(s.subscriber, e);
			}
			bus->raise_nesting -= 1;
			if (!bus->processing_post && bus->raise_nesting == 0)
			{
				bus->processing_post = true;
				AfterEventProcessingEvent event;
				bus->lists.SubList_AfterEventProcessingEvent.emit(bus, event);
				bus->processing_post = false;
			}
		}

		void emit(EventBus* bus, E&& e) { emit(bus, e); }
	};

#define RegisterSubList(E) \
	SubList<E> GLUE(SubList_,E)

	struct 
	{
		RegisterSubList(KeyPressedEvent);
		RegisterSubList(PlayerMovedEvent);
		RegisterSubList(PlayerAttackEvent);
		RegisterSubList(PlayerTryMoveEvent);
		RegisterSubList(AnimalDamagedEvent);
		RegisterSubList(AnimalDeathEvent);
		RegisterSubList(AfterEventProcessingEvent);
	} lists;

	
	EventBus()
	{
		const u32 s = sizeof(SubList<int>);
		u8* iter = (u8*)&lists;

		while ((u8*)iter < (u8*)&lists + sizeof(lists))
		{
			((SubListBase*)iter)->init();
			iter += s;
		}
	}
};

// clang doesnt want me to cast member pointers to normal pointers
// but it never expected this
template<typename TReturn, typename TSelf, typename... TArgs>
struct Converter
{
	typedef TReturn (*ptr)(void*, TArgs...);

	ptr operator()(TReturn (TSelf::* in)(TArgs...))
	{
		static union
		{
			TReturn (TSelf::* x)(TArgs...);
			TReturn (*y)(void*, TArgs...);
		} x {in};

		return x.y;
	}
};

#define SubscribeTo(E, F) \
	event_bus.lists.GLUE(SubList_,E).sub(this, Converter<void, std::remove_pointer_t<decltype(this)>, E&>()(&std::remove_pointer_t<decltype(this)>::F))

#define BRACED_INIT_LIST(...) { __VA_ARGS__ }
#define RaiseEvent(E, v) \
	event_bus.lists.GLUE(SubList_,E).emit(&event_bus, BRACED_INIT_LIST v);

EventBus event_bus;

struct Object;
typedef DList<Object> TileObjectList;

struct Object
{
	enum class Kind
	{
		Player,
	};

	vec2 pos;
	TileObjectList::Node* tile_node;

	// RTTI stuff
	virtual const void* objectId() = 0;
	template<typename T>
	b8 isa() { return &T::RTTI_ID == objectId(); }
};

#define ObjectRTTI \
	static const inline u8 RTTI_ID = 0; \
	const void* objectId() override { return &RTTI_ID; } \
	inline b8 isa(const void* id) { return id == &RTTI_ID; }


struct Player : Object
{
	ObjectRTTI;

	b8 init()
	{
		SubscribeTo(KeyPressedEvent, onKeyPress);
		SubscribeTo(AnimalDamagedEvent, onAnimalDamaged);
		SubscribeTo(AnimalDeathEvent, onAnimalDeath);
		return true;
	}

	template<typename... Args>
	void say(Args... args)
	{
		io::formatv(&fs::stdout, "Player: ", args..., "\n");
	}

	void tryMoveTo(vec2 newpos)
	{
		PlayerTryMoveEvent attempt = 
		{
			.player = this,
			.destination = newpos,
			.cancel = false
		};
		RaiseEvent(PlayerTryMoveEvent, (attempt));

		if (attempt.cancel)
			return;

		pos = newpos;
		RaiseEvent(PlayerMovedEvent, (this));
	}

	void onKeyPress(KeyPressedEvent& event)
	{
		switch (event.key)
		{
		case 'w':
			return tryMoveTo({pos.x, pos.y-1});
		case 'a':
			return tryMoveTo({pos.x-1, pos.y});
		case 's':
			return tryMoveTo({pos.x, pos.y+1});
		case 'd':
			return tryMoveTo({pos.x+1, pos.y});

		case 'i':
			RaiseEvent(PlayerAttackEvent, (this, {pos.x, pos.y-1}));
			return;
		case 'j':
			RaiseEvent(PlayerAttackEvent, (this, {pos.x-1, pos.y}));
			return;
		case 'k':
			RaiseEvent(PlayerAttackEvent, (this, {pos.x, pos.y+1}));
			return;
		case 'l':
			RaiseEvent(PlayerAttackEvent, (this, {pos.x+1, pos.y}));
			return;
		}
	}

	void onAnimalDamaged(AnimalDamagedEvent& event)
	{
		if (rand() % 2 == 0)
			say("Take that foul beast!");
	}

	void onAnimalDeath(AnimalDeathEvent& event)
	{
		say("Another creature slain");
	}
};

struct Animal : Object
{
	ObjectRTTI;

	s8 health = 100;

	b8 init()
	{
		SubscribeTo(PlayerAttackEvent, onPlayerAttack);
		return true;
	}

	void onPlayerAttack(PlayerAttackEvent& event)
	{
		if (event.attack_pos == pos)
		{
			if (health <= 0)
				return;

			io::formatv(&fs::stdout, "Animal: baaah!!\n");
			health -= 25;
			if (health <= 0)
			{
				RaiseEvent(AnimalDeathEvent, (this));
			}
			else
			{
				RaiseEvent(AnimalDamagedEvent, (this));
			}
		}
	}
};

struct Narrator
{
	b8 init()
	{
		SubscribeTo(PlayerAttackEvent, onPlayerAttack);
		SubscribeTo(PlayerMovedEvent, onPlayerMove);
		SubscribeTo(AnimalDeathEvent, onAnimalDeath);

		return true;
	}

	void onPlayerMove(PlayerMovedEvent& event)
	{
		io::formatv(&fs::stdout, "The player has moved to (", event.player->pos.x, ", ", event.player->pos.y, ")\n");
	}

	void onPlayerAttack(PlayerAttackEvent& event)
	{
		io::formatv(&fs::stdout, "The player has attacked position (", event.attack_pos.x, ", ", event.attack_pos.y, ")\n");
	}

	void onAnimalDeath(AnimalDeathEvent& event)
	{
		io::formatv(&fs::stdout, "The animal is slain by the player\n");
	}
};

struct Map
{
	struct Tile
	{
		enum class Kind
		{
			Empty,
			Wall
		} kind = Kind::Empty;

		DList<Object> objects; // on this tile

		b8 hasObject() { return !objects.isEmpty(); }
	};

	mem::Bump bump;
	SList<Object> deferred_removal;

	static const u32 mapsize = 5;
	static const u32 maparea = mapsize*mapsize;

	Tile tiles[maparea] = {};

	vec2 getTilePosFromOffset(s32 offset) { return {s32(offset % mapsize), s32(offset / mapsize)}; }

	Tile& getTile(vec2 pos) { return tiles[pos.x + mapsize * pos.y]; }

	b8 init(str initstr)
	{
		if (!bump.init())
			return false;

		deferred_removal = SList<Object>::create();

		for (u32 i = 0; i < maparea; ++i)
		{
			// initial initialization
			tiles[i].objects = TileObjectList::create(&bump);
		}

		u32 tileidx = 0;
		while (!initstr.isEmpty() && tileidx < maparea)
		{
			using enum Tile::Kind;

			switch (initstr.advance().codepoint)
			{
			case 'X':
				tiles[tileidx].kind = Wall;
				tileidx += 1;
				break;
			case 'P':
				{
					Player* p = bump.construct<Player>();
					p->pos = getTilePosFromOffset(tileidx);
					p->init();
					p->tile_node = tiles[tileidx].objects.pushHead(p);
				}
				tileidx += 1;
				break;
			case 'A':
				{
					Animal* a = bump.construct<Animal>();
					a->pos = getTilePosFromOffset(tileidx);
					a->init();
					a->tile_node = tiles[tileidx].objects.pushTail(a);
				}
				tileidx += 1;
				break;
			case '.':
				tiles[tileidx].kind = Empty;
				tileidx += 1;
				break;
			}
		}

		SubscribeTo(PlayerTryMoveEvent, onPlayerTryMove);
		SubscribeTo(PlayerMovedEvent, onPlayerMoved);
		SubscribeTo(AnimalDeathEvent, onAnimalDeath);
		SubscribeTo(AfterEventProcessingEvent, afterEventProcessing);

		return true;
	}

	vec2 old_player_pos; // kind scuffed
	void onPlayerTryMove(PlayerTryMoveEvent& event)
	{
		if (getTile(event.destination).kind == Tile::Kind::Wall)
			event.cancel = true;
		old_player_pos = event.player->pos;
	}

	void onPlayerMoved(PlayerMovedEvent& event)
	{
		Player& player = *event.player;

		// remove from old tile and put in new one
		getTile(old_player_pos).objects.destroy(player.tile_node);
		player.tile_node = getTile(player.pos).objects.pushHead(&player);
	}

	void onAnimalDeath(AnimalDeathEvent& event)
	{
		deferred_removal.push(event.animal);
	}

	void afterEventProcessing(AfterEventProcessingEvent& event)
	{
		for (auto& o : deferred_removal)
		{
			Tile& tile = getTile(o.pos);
			tile.objects.destroy(o.tile_node);
		}
	}

	void render()
	{
		for (s32 y = 0; y < mapsize; ++y)
		{
			for (s32 x = 0; x < mapsize; ++x)
			{
				Tile& tile = getTile({x, y});

				if (tile.kind == Tile::Kind::Wall)
				{
					io::format(&fs::stdout, 'X');
					continue;
				}

				if (tile.hasObject())
				{
					char c = '?';

					// figure out which one to display
					for (auto& o : tile.objects)
					{
						if (o.isa<Player>())
						{
							c = 'P';
							break; // always display player if they're in the tile
						}
						else if (o.isa<Animal>())
						{
							c = 'A';
						}
					}

					io::format(&fs::stdout, c);
				}
				else
				{
					io::format(&fs::stdout, ' ');
				}
			}
			io::format(&fs::stdout, '\n');
		}
	}
};

int main()
{
	platform::TermSettings settings = platform::termSetNonCanonical();
	defer { platform::termRestoreSettings(settings); };

	Map map;

	map.init(R"(
		XXXXX
		X.A.X
		X..AX
		XP..X
		XXXXX
	)"_str);

	map.bump.construct<Narrator>()->init();

	for (;;)
	{
		u8 c;
		fs::stdin.read({&c, 1});
		RaiseEvent(KeyPressedEvent, (c));
		map.render();
	}
}
