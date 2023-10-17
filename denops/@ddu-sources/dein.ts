import {
  ActionArguments,
  ActionFlags,
  BaseSource,
  DduItem,
  Item,
} from "https://deno.land/x/ddu_vim@v3.6.0/types.ts";
import { Denops } from "https://deno.land/x/ddu_vim@v3.6.0/deps.ts";
import { ActionData } from "https://deno.land/x/ddu_kind_file@v0.7.1/file.ts";

type Params = Record<string, never>;

type Action = {
  path: string;
  __name: string;
};

type Dein = {
  name: string;
  path: string;
};

export class Source extends BaseSource<Params> {
  override kind = "file";

  override gather(args: {
    denops: Denops;
    sourceParams: Params;
  }): ReadableStream<Item<ActionData>[]> {
    return new ReadableStream({
      async start(controller) {
        const deins = Object.values(
          await args.denops.call("dein#get") as Record<string, Dein>,
        );
        const items = deins.map((dein) => {
          return {
            word: dein.name,
            action: {
              path: dein.path,
              __name: dein.name,
            } as Action,
          };
        });

        controller.enqueue(items);

        controller.close();
      },
    });
  }

  override actions: Record<
    string,
    (args: ActionArguments<Params>) => Promise<ActionFlags>
  > = {
    update: async (args: { denops: Denops; items: DduItem[] }) => {
      const plugins = args.items.map((item) => (item.action as Action).__name);
      await args.denops.call("dein#update", plugins);

      return Promise.resolve(ActionFlags.None);
    },
  };

  override params(): Params {
    return {};
  }
}
